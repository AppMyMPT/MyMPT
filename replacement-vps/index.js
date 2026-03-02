/**
 * Сервис проверки замен МПТ для запуска на VPS (Docker).
 * Раз в час парсит https://mpt.ru/izmeneniya-v-raspisanii/,
 * сравнивает с последним состоянием (файл на диске), отправляет FCM.
 * Читает токены из Firestore (Firebase Admin SDK).
 */

const admin = require("firebase-admin");
const axios = require("axios");
const cheerio = require("cheerio");
const cron = require("node-cron");
const fs = require("fs");
const path = require("path");
const log = require("./logger");

const REPLACEMENTS_URL = "https://mpt.ru/izmeneniya-v-raspisanii/";
const FCM_TOKENS_COLLECTION = "fcm_tokens";

const STATE_FILE =
  process.env.STATE_FILE ||
  path.join(process.env.DATA_DIR || "./data", "last_replacements.json");
const CREDENTIALS_PATH =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, "firebase-service-account.json");

function ensureDataDir() {
  const dir = path.dirname(STATE_FILE);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
    log.debug("Создана папка данных:", dir);
  }
}

function loadLastState() {
  ensureDataDir();
  try {
    const raw = fs.readFileSync(STATE_FILE, "utf8");
    const state = JSON.parse(raw);
    const keys = Object.keys(state);
    log.debug("Загружено последнее состояние из", STATE_FILE, "групп:", keys.length, keys);
    return state;
  } catch (e) {
    if (e.code === "ENOENT") {
      log.debug("Файла состояния нет, начинаем с нуля");
      return {};
    }
    throw e;
  }
}

function saveLastState(state) {
  ensureDataDir();
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2), "utf8");
  log.debug("Состояние сохранено в", STATE_FILE, "групп:", Object.keys(state).length);
}

function normalizeGroupCode(input) {
  if (!input || typeof input !== "string") return "";
  let s = input
    .replace(/—/g, "-")
    .replace(/–/g, "-")
    .replace(/−/g, "-")
    .trim()
    .toUpperCase();
  s = s.replace(/\s+/g, " ").replace(/\s*-\s*/g, "-");
  return s;
}

function splitGroupCodes(raw) {
  if (!raw || typeof raw !== "string") return [];
  const parts = raw.replace(/\n/g, " ").split(/[,/;]/);
  const seen = new Set();
  const out = [];
  for (const p of parts) {
    const v = normalizeGroupCode(p);
    if (!v || seen.has(v)) continue;
    seen.add(v);
    out.push(v);
  }
  return out;
}

function captionMatchesGroup(captionText, groupCode) {
  const normalized = normalizeGroupCode(captionText);
  const normalizedGroup = normalizeGroupCode(groupCode);
  if (!normalizedGroup) return false;
  if (normalized.includes(normalizedGroup)) return true;
  const candidates = splitGroupCodes(groupCode);
  return candidates.some((c) => c && normalized.includes(c));
}

function getDateStrings() {
  const now = new Date();
  const today = [
    String(now.getDate()).padStart(2, "0"),
    String(now.getMonth() + 1).padStart(2, "0"),
    now.getFullYear(),
  ].join(".");
  const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  const tomorrowStr = [
    String(tomorrow.getDate()).padStart(2, "0"),
    String(tomorrow.getMonth() + 1).padStart(2, "0"),
    tomorrow.getFullYear(),
  ].join(".");
  return { today: today, tomorrow: tomorrowStr };
}

function parseReplacementsByGroup(html) {
  const $ = cheerio.load(html);
  const result = new Map();
  const { today, tomorrow } = getDateStrings();
  const dateRegExp = /(\d{2}\.\d{2}\.\d{4})/;

  $("h4").each((_, el) => {
    const text = $(el).text().trim();
    if (!text.startsWith("Замены на")) return;
    const match = text.match(dateRegExp);
    if (!match) return;
    const currentDate = match[1];
    if (currentDate !== today && currentDate !== tomorrow) return;

    let next = $(el).next();
    while (next.length) {
      const tag = next.prop("tagName") && next.prop("tagName").toLowerCase();
      const nextText = next.text().trim();
      if (tag === "h4" && nextText.startsWith("Замены на")) break;

      let table = null;
      if (tag === "div" && next.hasClass("table-responsive")) {
        table = next.find("table.table").first();
      } else if (tag === "table" && next.hasClass("table")) {
        table = next;
      }

      if (table && table.length) {
        const caption = table.find("caption");
        if (caption.length) {
          const captionText = caption.text().trim();
          const rows = [];
          table.find("tbody tr, tr").each((_, row) => {
            const cells = $(row).find("td");
            if (cells.length !== 4) return;
            rows.push({
              lessonNumber: $(cells[0]).text().trim(),
              replaceFrom: $(cells[1]).text().trim(),
              replaceTo: $(cells[2]).text().trim(),
              updatedAt: $(cells[3]).text().trim(),
              changeDate: currentDate,
            });
          });
          if (!result.has(captionText)) result.set(captionText, []);
          result.get(captionText).push(...rows);
        }
      }
      next = next.next();
    }
  });

  const totalRows = [...result.values()].reduce((s, rows) => s + rows.length, 0);
  log.debug(
    "Распарсены замены: блоков=",
    result.size,
    "подписи=",
    [...result.keys()],
    "всего строк=",
    totalRows
  );
  return result;
}

function getReplacementsForGroup(parsedByCaption, groupCode) {
  const seen = new Set();
  const list = [];
  for (const [caption, replacements] of parsedByCaption) {
    if (!captionMatchesGroup(caption, groupCode)) continue;
    for (const r of replacements) {
      const h = replacementHash(r);
      if (seen.has(h)) continue;
      seen.add(h);
      list.push(r);
    }
  }
  return list;
}

function replacementHash(r) {
  return `${r.lessonNumber}_${r.replaceFrom}_${r.replaceTo}_${r.changeDate}_${r.updatedAt}`;
}

function hasNewReplacements(current, lastHashes) {
  if (!lastHashes || lastHashes.length === 0) return current.length > 0;
  const currentSet = new Set(current.map(replacementHash));
  for (const h of lastHashes) {
    if (!currentSet.has(h)) return true;
  }
  return current.length > lastHashes.length;
}

function groupDocId(groupCode) {
  return String(groupCode).replace(/\//g, "_").trim() || "_empty";
}

async function runCheck() {
  log.info("Проверка запущена", { url: REPLACEMENTS_URL });

  const db = admin.firestore();
  const messaging = admin.messaging();
  const state = loadLastState();

  let html;
  try {
    const res = await axios.get(REPLACEMENTS_URL, {
      timeout: 15000,
      responseType: "text",
      headers: { "User-Agent": "MymptReplacementService/1.0" },
    });
    html = res.data;
    log.info("Страница загружена", { status: res.status, length: html.length });
  } catch (e) {
    log.error("Ошибка загрузки страницы", e.message, e.code || "");
    return;
  }

  const parsedByCaption = parseReplacementsByGroup(html);
  if (parsedByCaption.size === 0) {
    log.info("Нет блоков замен на сегодня/завтра, пропуск");
    return;
  }

  const tokensSnap = await db.collection(FCM_TOKENS_COLLECTION).get();
  const tokensByGroup = new Map();
  for (const doc of tokensSnap.docs) {
    const data = doc.data();
    const token = data.token;
    const groupCode = (data.groupCode || "").trim();
    if (!token || !groupCode) continue;
    if (!tokensByGroup.has(groupCode)) tokensByGroup.set(groupCode, []);
    tokensByGroup.get(groupCode).push({ token, docRef: doc.ref });
  }
  log.info("Загружены FCM-токены", { groups: tokensByGroup.size, docs: tokensSnap.size });

  for (const [groupCode, tokens] of tokensByGroup) {
    const replacements = getReplacementsForGroup(parsedByCaption, groupCode);
    const key = groupDocId(groupCode);
    const lastHashes = state[key] && state[key].hashes ? state[key].hashes : [];

    if (!hasNewReplacements(replacements, lastHashes)) {
      log.debug("Нет новых замен для группы", groupCode);
      continue;
    }

    // Не уведомлять, если замен для группы нет (раньше были — сняли). Только обновить state.
    if (replacements.length === 0) {
      log.debug("Замены для группы сняты, обновляем state без уведомления", groupCode);
      state[key] = {
        groupCode,
        hashes: [],
        updatedAt: new Date().toISOString(),
      };
      continue;
    }

    log.info("Новые замены для группы", groupCode, "количество:", replacements.length, "токенов:", tokens.length);

    const title =
      replacements.length === 1
        ? "Новая замена в расписании"
        : "Новые замены в расписании";
    const first = replacements[0];
    const body =
      replacements.length === 1
        ? `${first.changeDate}: Пара ${first.lessonNumber}: ${first.replaceFrom} → ${first.replaceTo}`
        : `Обнаружено новых замен: ${replacements.length}`;

    let sentCount = 0;
    for (const { token, docRef } of tokens) {
      try {
        await messaging.send({
          token,
          notification: { title, body },
          android: { priority: "high" },
        });
        sentCount++;
      } catch (sendErr) {
        if (
          sendErr.code === "messaging/invalid-registration-token" ||
          sendErr.code === "messaging/registration-token-not-registered"
        ) {
          try {
            await docRef.delete();
            log.info("Удалён недействительный токен", docRef.id);
          } catch (_) {}
        }
        log.warn("Ошибка отправки FCM", docRef.id, sendErr.message, sendErr.code || "");
      }
    }
    if (sentCount > 0) {
      log.info("FCM отправлены", groupCode, "успешно:", sentCount, "из", tokens.length);
    }

    state[key] = {
      groupCode,
      hashes: replacements.map(replacementHash),
      updatedAt: new Date().toISOString(),
    };
  }

  saveLastState(state);
  log.info("Проверка завершена");
}

function main() {
  log.info("Запуск mpt-replacement-service", {
    stateFile: STATE_FILE,
    logFile: log.getLogPath ? log.getLogPath() : "только stdout",
  });

  if (!fs.existsSync(CREDENTIALS_PATH)) {
    log.error(
      "Файл учётных данных Firebase не найден. Задайте GOOGLE_APPLICATION_CREDENTIALS или положите firebase-service-account.json в папку приложения."
    );
    process.exit(1);
  }

  const key = JSON.parse(fs.readFileSync(CREDENTIALS_PATH, "utf8"));
  admin.initializeApp({ credential: admin.credential.cert(key) });
  log.info("Firebase инициализирован");

  const runEveryHour = process.env.CRON_SCHEDULE || "0 * * * *";
  log.info("Планировщик: проверка по cron:", runEveryHour);

  if (process.env.RUN_ONCE === "1") {
    runCheck()
      .then(() => process.exit(0))
      .catch((e) => {
        log.error("Проверка завершилась с ошибкой", e.message, e.stack);
        process.exit(1);
      });
    return;
  }

  runCheck().catch((e) => log.error("Проверка: ошибка", e.message, e.stack));
  cron.schedule(runEveryHour, () => {
    runCheck().catch((e) => log.error("Проверка: ошибка", e.message, e.stack));
  });
}

main();
