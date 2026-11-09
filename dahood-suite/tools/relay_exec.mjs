// Talks to the local roblox-executor-mcp bridge the same way its MCP tools do (relay socket),
// but with a per-request targetClientId, which the MCP tool set-active-client cannot set from a secondary.
// usage: node relay_exec.mjs <get|run> <clientId> <lua-file>
//   get = type "get-data-by-code" (returns serialized values), run = type "execute" (fire and forget)
import { readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";

const [, , mode, clientId, file] = process.argv;
if (!mode || !clientId || !file) {
  console.error("usage: node relay_exec.mjs <get|run> <clientId> <lua-file>");
  process.exit(64);
}
const code = readFileSync(file, "utf8");
const id = randomUUID();
const type = mode === "get" ? "get-data-by-code" : "execute";
const source = (mode === "get" ? "setthreadidentity(8);" : "setthreadidentity(8)\n") + code;

const ws = new WebSocket("ws://localhost:16384/mcp-relay");
const timer = setTimeout(() => {
  console.log("TIMEOUT (no response in 15 s)");
  process.exit(2);
}, 15000);

ws.addEventListener("open", () => {
  // the tools spread their `data` into the top level of the message: { id, ...data, type }
  ws.send(JSON.stringify({ id, source, type, targetClientId: clientId }));
  if (mode === "run") {
    // fire-and-forget: give the bridge a moment to forward it, then leave
    setTimeout(() => {
      console.log("SENT");
      process.exit(0);
    }, 800);
  }
});
ws.addEventListener("message", (event) => {
  let message;
  try {
    message = JSON.parse(String(event.data));
  } catch {
    return;
  }
  if (message.id !== id) return;
  clearTimeout(timer);
  console.log(JSON.stringify(message));
  ws.close();
  process.exit(message.error ? 1 : 0);
});
ws.addEventListener("error", (event) => {
  console.log("SOCKET ERROR", event?.message ?? "");
  process.exit(3);
});
