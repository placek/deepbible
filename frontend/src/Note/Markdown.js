export const markdownToHtml = (markdown) => {
  const value = typeof markdown === "string" ? markdown : "";

  if (globalThis.marked && typeof globalThis.marked.parse === "function") {
    return globalThis.marked.parse(value, { breaks: true });
  }

  const escaped = value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");

  return escaped.replace(/\n/g, "<br>");
};
