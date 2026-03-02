/**
 * Простой логгер для mpt-replacement-service.
 * Уровни: debug, info, warn, error.
 * Пишет в stdout и опционально в файл (в папке сервиса или DATA_DIR/logs).
 */

const fs = require("fs");
const path = require("path");

const LEVELS = { debug: 0, info: 1, warn: 2, error: 3 };
const LOG_LEVEL = (process.env.LOG_LEVEL || "info").toLowerCase();
const MIN_LEVEL = LEVELS[LOG_LEVEL] ?? LEVELS.info;

const LOG_DIR =
  process.env.LOG_DIR ||
  path.join(process.env.DATA_DIR || path.join(__dirname, "data"), "logs");
const LOG_FILE = process.env.LOG_FILE || path.join(LOG_DIR, "service.log");

let stream = null;

function ensureLogDir() {
  if (!fs.existsSync(LOG_DIR)) {
    fs.mkdirSync(LOG_DIR, { recursive: true });
  }
}

function getStream() {
  if (stream) return stream;
  ensureLogDir();
  stream = fs.createWriteStream(LOG_FILE, { flags: "a" });
  return stream;
}

function format(level, ...args) {
  const ts = new Date().toISOString();
  const msg = args
    .map((a) => (typeof a === "object" ? JSON.stringify(a) : String(a)))
    .join(" ");
  return `[${ts}] [${level.toUpperCase()}] ${msg}\n`;
}

function write(level, ...args) {
  const line = format(level, ...args);
  process.stdout.write(line);
  try {
    getStream().write(line);
  } catch (e) {
    process.stderr.write(`[логгер] ошибка записи: ${e.message}\n`);
  }
}

function log(level, ...args) {
  if (LEVELS[level] >= MIN_LEVEL) {
    write(level, ...args);
  }
}

module.exports = {
  debug: (...args) => log("debug", ...args),
  info: (...args) => log("info", ...args),
  warn: (...args) => log("warn", ...args),
  error: (...args) => log("error", ...args),
  child(prefix) {
    return {
      debug: (...a) => log("debug", prefix, ...a),
      info: (...a) => log("info", prefix, ...a),
      warn: (...a) => log("warn", prefix, ...a),
      error: (...a) => log("error", prefix, ...a),
    };
  },
  getLogPath: () => LOG_FILE,
  getLogDir: () => LOG_DIR,
};
