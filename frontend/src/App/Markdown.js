export const htmlToText = (html) => {
  const value = typeof html === "string" ? html : "";
  if (value === "") {
    return "";
  }

  const container = document.createElement("div");
  container.innerHTML = value;
  const text = container.textContent || "";

  return text.replace(/\s+/g, " ").trim();
};

export const stripSmTags = (input) => {
  const value = typeof input === "string" ? input : "";
  if (value === "") {
    return "";
  }

  return value
    .replace(/<\/?s\b[^>]*>/gi, "")
    .replace(/<\/?m\b[^>]*>/gi, "");
};

export const slugify = (text) => {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
};

export const downloadMarkdownFile = (filename) => (content) => () => {
  const safeName = typeof filename === "string" && filename.length > 0
    ? filename
    : "deepbible-sheet.md";
  const text = typeof content === "string" ? content : "";
  const blob = new Blob([text], { type: "text/markdown;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");

  link.href = url;
  link.download = safeName;
  link.style.display = "none";
  document.body.appendChild(link);
  link.click();

  setTimeout(() => {
    URL.revokeObjectURL(url);
    link.remove();
  }, 0);
};
