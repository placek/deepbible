const HASH_KEY = "state";

const textEncoder = typeof TextEncoder !== "undefined" ? new TextEncoder() : null;
const textDecoder = typeof TextDecoder !== "undefined" ? new TextDecoder() : null;

const base64urlEncode = bytes => {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  const base64 = btoa(binary);
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
};

const base64urlDecode = encoded => {
  const normalized = encoded.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(normalized.length + (4 - (normalized.length % 4)) % 4, "=");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
};

const readLegacySeeds = () => {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("pericopes");
  if (!raw) {
    return [];
  }

  const seeds = [];
  const entries = raw.split("|");
  for (const entry of entries) {
    if (!entry) continue;
    const parts = entry.split("~");
    if (parts.length !== 2) continue;
    const [addressPart, sourcePart] = parts;
    try {
      const address = decodeURIComponent(addressPart).replace(/_/gi, " ").replace(/\*/gi, ",");
      const source = decodeURIComponent(sourcePart);
      seeds.push({ address, source });
    } catch (_err) {
      // ignore malformed entries
    }
  }
  return seeds;
};

const encodeSeeds = seeds => {
  if (!Array.isArray(seeds) || seeds.length === 0 || !window.pako || !textEncoder) {
    return "";
  }
  const state = { pericopes: seeds };
  const json = JSON.stringify(state);
  const compressed = window.pako.deflate(textEncoder.encode(json));
  return base64urlEncode(compressed);
};

const decodeSeeds = encoded => {
  if (!encoded || !window.pako || !textDecoder) {
    return [];
  }
  try {
    const inflated = window.pako.inflate(base64urlDecode(encoded));
    const json = textDecoder.decode(inflated);
    const parsed = JSON.parse(json);
    if (parsed && Array.isArray(parsed.pericopes)) {
      return parsed.pericopes.map(seed => ({
        address: typeof seed.address === "string" ? seed.address : "",
        source: typeof seed.source === "string" ? seed.source : "",
      })).filter(seed => seed.address || seed.source);
    }
  } catch (_err) {
    // ignore malformed state
  }
  return [];
};

const currentHashValue = () => {
  const raw = window.location.hash.startsWith("#")
    ? window.location.hash.slice(1)
    : window.location.hash;
  if (!raw) return "";
  if (raw.startsWith(`${HASH_KEY}=`)) {
    return raw.slice(HASH_KEY.length + 1);
  }
  return raw;
};

const buildUrl = (hashValue) => {
  const params = new URLSearchParams(window.location.search);
  params.delete("pericopes");
  const search = params.toString();
  const hash = hashValue ? `#${HASH_KEY}=${hashValue}` : "";
  return `${window.location.pathname}${search ? `?${search}` : ""}${hash}`;
};

export const loadSeeds = () => {
  if (typeof window === "undefined") {
    return [];
  }

  const hashValue = currentHashValue();
  let seeds = decodeSeeds(hashValue);

  if (seeds.length === 0) {
    seeds = readLegacySeeds();
  }

  const encoded = encodeSeeds(seeds);
  const newUrl = buildUrl(encoded);

  window.history.replaceState({ pericopes: seeds }, "", newUrl);

  if (!window.__deepbibleHistoryListener) {
    window.addEventListener("popstate", () => {
      window.location.reload();
    });
    window.__deepbibleHistoryListener = true;
  }

  return seeds;
};

export const storeSeeds = seeds => () => {
  if (typeof window === "undefined") {
    return;
  }

  const sanitized = Array.isArray(seeds)
    ? seeds
      .map(seed => ({
        address: typeof seed.address === "string" ? seed.address : "",
        source: typeof seed.source === "string" ? seed.source : "",
      }))
      .filter(seed => seed.address || seed.source)
    : [];

  const encoded = encodeSeeds(sanitized);
  const newUrl = buildUrl(encoded);
  const currentUrl = `${window.location.pathname}${window.location.search}${window.location.hash}`;
  const state = { pericopes: sanitized };

  if (currentUrl === newUrl) {
    window.history.replaceState(state, "", newUrl);
  } else {
    window.history.pushState(state, "", newUrl);
  }
};
