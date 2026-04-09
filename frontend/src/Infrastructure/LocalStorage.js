const STORAGE_KEY = "deepbible:sheets";

const readMap = () => {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    return typeof parsed === "object" && parsed !== null ? parsed : {};
  } catch (_) {
    return {};
  }
};

const writeMap = (map) => {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(map));
};

export const saveSheetToLocal = (sheetId) => (json) => () => {
  if (!sheetId) return;
  const map = readMap();
  const title =
    json && typeof json.title === "string" ? json.title : "";
  map[sheetId] = {
    title,
    savedAt: new Date().toISOString(),
    items: json && Array.isArray(json.items) ? json.items : [],
  };
  writeMap(map);
};

export const loadSheetList = () => {
  const map = readMap();
  return Object.entries(map)
    .map(([sheetId, entry]) => ({
      sheetId,
      title: entry.title || "",
      savedAt: entry.savedAt || "",
    }))
    .sort((a, b) => (b.savedAt > a.savedAt ? 1 : -1));
};

export const deleteSheetFromLocal = (sheetId) => () => {
  const map = readMap();
  delete map[sheetId];
  writeMap(map);
};

export const navigateToSheet = (sheetId) => () => {
  const params = new URLSearchParams(window.location.search);
  params.set("sheet", sheetId);
  window.location.search = params.toString();
};
