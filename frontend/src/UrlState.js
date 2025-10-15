export const loadSeeds = () => {
  if (typeof window === "undefined") {
    return [];
  }

  const params = new URLSearchParams(window.location.search);
  const raw = params.get("pericopes");
  if (!raw) {
    return [];
  }

  const seeds = [];
  const entries = raw.split("|");
  for (const entry of entries) {
    if (!entry) {
      continue;
    }
    const parts = entry.split("~");
    if (parts.length !== 2) {
      continue;
    }
    const [addressPart, sourcePart] = parts;
    try {
      const address = decodeURIComponent(addressPart);
      const source = decodeURIComponent(sourcePart);
      seeds.push({ address, source });
    } catch (_err) {
      // ignore malformed entries
    }
  }

  const currentUrl =
    window.location.pathname + window.location.search + window.location.hash;

  window.history.replaceState({ pericopes: seeds }, "", currentUrl);

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

  const params = new URLSearchParams(window.location.search);

  if (!Array.isArray(seeds) || seeds.length === 0) {
    params.delete("pericopes");
  } else {
    const encoded = [];
    for (const seed of seeds) {
      if (!seed) {
        continue;
      }
      const address = typeof seed.address === "string" ? seed.address : "";
      const source = typeof seed.source === "string" ? seed.source : "";
      encoded.push(
        encodeURIComponent(address) + "~" + encodeURIComponent(source)
      );
    }
    if (encoded.length === 0) {
      params.delete("pericopes");
    } else {
      params.set("pericopes", encoded.join("|"));
    }
  }

  const search = params.toString();
  const newUrl =
    window.location.pathname +
    (search ? "?" + search : "") +
    window.location.hash;

  const currentUrl =
    window.location.pathname + window.location.search + window.location.hash;

  const state = { pericopes: seeds };

  if (currentUrl === newUrl) {
    window.history.replaceState(state, "", newUrl);
  } else {
    window.history.pushState(state, "", newUrl);
  }
};
