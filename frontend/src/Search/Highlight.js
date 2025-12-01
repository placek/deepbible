export function splitSearchInput(input) {
  const pattern = /(@\S+)|(~\S*(\s+\d+(,[\d\-.]+)?)?)/g;
  const segments = [];
  let lastIndex = 0;
  let match;

  while ((match = pattern.exec(input)) !== null) {
    const start = match.index;

    if (start > lastIndex) {
      segments.push({ text: input.slice(lastIndex, start), color: null });
    }

    const matchedText = match[0];
    const color = match[1] ? "yellow" : "red";

    segments.push({ text: matchedText, color });
    lastIndex = pattern.lastIndex;
  }

  if (lastIndex < input.length) {
    segments.push({ text: input.slice(lastIndex), color: null });
  }

  return segments;
}
