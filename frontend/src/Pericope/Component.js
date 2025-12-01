export const annotateCommentaryLinks = (source) => (html) => {
  if (typeof document === "undefined") {
    return html;
  }

  const template = document.createElement("template");
  template.innerHTML = html;

  template.content.querySelectorAll("a.B").forEach((link) => {
    link.dataset.source = source;
    link.dataset.address = link.innerHTML;
  });

  return template.innerHTML;
};
