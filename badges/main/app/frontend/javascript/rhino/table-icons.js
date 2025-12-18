import { html, svg } from "lit";

function toSvg(path, size = 24) {
  return html`
    <svg
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
      fill="currentColor"
      viewBox="0 0 ${size} ${size}"
      width="${size}px"
      height="${size}px"
      part="toolbar__icon"
    >
      ${path}
    </svg>
  `
}

export const insertTable = toSvg(
  svg`<path pid="0" fill-rule="evenodd" d="M17 17v5h2a3 3 0 0 0 3-3v-2h-5zm-2 0H9v5h6v-5zm2-2h5V9h-5v6zm-2 0V9H9v6h6zm2-8h5V5a3 3 0 0 0-3-3h-2v5zm-2 0V2H9v5h6zm9 9.177V19a5 5 0 0 1-5 5H5a5 5 0 0 1-5-5V5a5 5 0 0 1 5-5h14a5 5 0 0 1 5 5v2.823a.843.843 0 0 1 0 .354v7.646a.843.843 0 0 1 0 .354zM7 2H5a3 3 0 0 0-3 3v2h5V2zM2 9v6h5V9H2zm0 8v2a3 3 0 0 0 3 3h2v-5H2z"></path>`
);

export const deleteTable = toSvg(
  svg`<path pid="0" d="M19 14a5 5 0 1 1 0 10 5 5 0 0 1 0-10zm-2.5 5.938h5a.937.937 0 1 0 0-1.875h-5a.937.937 0 1 0 0 1.875zM12.29 17H9v5h3.674c.356.75.841 1.426 1.427 2H5a5 5 0 0 1-5-5V5a5 5 0 0 1 5-5h14a5 5 0 0 1 5 5v2.823a.843.843 0 0 1 0 .354V14.1a7.018 7.018 0 0 0-2-1.427V9h-5v3.29a6.972 6.972 0 0 0-2 .965V9H9v6h4.255a6.972 6.972 0 0 0-.965 2zM17 7h5V5a3 3 0 0 0-3-3h-2v5zm-2 0V2H9v5h6zM7 2H5a3 3 0 0 0-3 3v2h5V2zM2 9v6h5V9H2zm0 8v2a3 3 0 0 0 3 3h2v-5H2z"></path>`
);

export const addColumnBefore = toSvg(
  svg`<path pid="0" d="M19 14a5 5 0 1 1 0 10 5 5 0 0 1 0-10zm2.5 5.938a.937.937 0 1 0 0-1.875h-1.25a.312.312 0 0 1-.313-.313V16.5a.937.937 0 1 0-1.875 0v1.25c0 .173-.14.313-.312.313H16.5a.937.937 0 1 0 0 1.875h1.25c.173 0 .313.14.313.312v1.25a.937.937 0 1 0 1.875 0v-1.25c0-.173.14-.313.312-.313h1.25zM2 19a3 3 0 0 0 6 0V5a3 3 0 1 0-6 0v14zm-2 0V5a5 5 0 1 1 10 0v14a5 5 0 0 1-10 0z"></path>`
);

export const addColumnAfter = toSvg(
  svg`<path pid="0" d="M5 14a5 5 0 1 1 0 10 5 5 0 0 1 0-10zm2.5 5.938a.937.937 0 1 0 0-1.875H6.25a.312.312 0 0 1-.313-.313V16.5a.937.937 0 1 0-1.875 0v1.25c0 .173-.14.313-.312.313H2.5a.937.937 0 1 0 0 1.875h1.25c.173 0 .313.14.313.312v1.25a.937.937 0 1 0 1.875 0v-1.25c0-.173.14-.313.312-.313H7.5zM16 19a3 3 0 0 0 6 0V5a3 3 0 0 0-6 0v14zm-2 0V5a5 5 0 0 1 10 0v14a5 5 0 0 1-10 0z"></path>`
);

export const deleteColumn = toSvg(
  svg`<path pid="0" d="M12.641 21.931a7.01 7.01 0 0 0 1.146 1.74A5 5 0 0 1 7 19V5a5 5 0 1 1 10 0v7.29a6.972 6.972 0 0 0-2 .965V5a3 3 0 0 0-6 0v14a3 3 0 0 0 3.641 2.931zM19 14a5 5 0 1 1 0 10 5 5 0 0 1 0-10zm-2.5 5.938h5a.937.937 0 1 0 0-1.875h-5a.937.937 0 1 0 0 1.875z"></path>`
);

export const addRowBefore = toSvg(
  svg`<path pid="0" d="M19 14a5 5 0 1 1 0 10 5 5 0 0 1 0-10zm2.5 5.938a.937.937 0 1 0 0-1.875h-1.25a.312.312 0 0 1-.313-.313V16.5a.937.937 0 1 0-1.875 0v1.25c0 .173-.14.313-.312.313H16.5a.937.937 0 1 0 0 1.875h1.25c.173 0 .313.14.313.312v1.25a.937.937 0 1 0 1.875 0v-1.25c0-.173.14-.313.312-.313h1.25zM5 2a3 3 0 1 0 0 6h14a3 3 0 0 0 0-6H5zm0-2h14a5 5 0 0 1 0 10H5A5 5 0 1 1 5 0z"></path>`
);

export const addRowAfter = toSvg(
  svg`<path pid="0" d="M19 0a5 5 0 1 1 0 10 5 5 0 0 1 0-10zm2.5 5.938a.937.937 0 1 0 0-1.875h-1.25a.312.312 0 0 1-.313-.313V2.5a.937.937 0 1 0-1.875 0v1.25c0 .173-.14.313-.312.313H16.5a.937.937 0 1 0 0 1.875h1.25c.173 0 .313.14.313.312V7.5a.937.937 0 1 0 1.875 0V6.25c0-.173.14-.313.312-.313h1.25zM5 16a3 3 0 0 0 0 6h14a3 3 0 0 0 0-6H5zm0-2h14a5 5 0 0 1 0 10H5a5 5 0 0 1 0-10z"></path>`
);

export const deleteRow = toSvg(
  svg`<path pid="0" d="M13.255 15a6.972 6.972 0 0 0-.965 2H5A5 5 0 0 1 5 7h14a5 5 0 0 1 4.671 6.787 7.01 7.01 0 0 0-1.74-1.146A3 3 0 0 0 19 9H5a3 3 0 0 0 0 6h8.255zM19 14a5 5 0 1 1 0 10 5 5 0 0 1 0-10zm-2.5 5.938h5a.937.937 0 1 0 0-1.875h-5a.937.937 0 1 0 0 1.875z"></path>`
);

export const mergeCells = toSvg(
  svg``
);

export const splitCells = toSvg(
  svg``
);

export const toggleHeaderColumn = toSvg(
  svg`<path d="M 23.5625 0 c 1.3439 0 2.4375 1.0936 2.4375 2.4375 v 21.125 c 0 1.3439 -1.0936 2.4375 -2.4375 2.4375 H 2.4375 c -1.3439 0 -2.4375 -1.0936 -2.4375 -2.4375 V 2.4375 C 0 1.0936 1.0936 0 2.4375 0 h 21.125 Z m 0.8125 17.875 h -6.5 v 6.5 h 5.6875 c 0.4469 0 0.8125 -0.3656 0.8125 -0.8125 v -5.6875 Z m -8.125 0 H 9.75 v 6.5 h 6.5 v -6.5 Z m 8.125 -8.125 h -6.5 v 6.5 h 6.5 V 9.75 Z m -8.125 0 H 9.75 v 6.5 h 6.5 V 9.75 Z m 7.3125 -8.125 h -5.6875 v 6.5 h 6.5 V 2.4375 c 0 -0.4469 -0.3656 -0.8125 -0.8125 -0.8125 Z m -7.3125 0 H 9.75 v 6.5 h 6.5 V 1.625 Z" fill-rule="evenodd"/>`
);
  
export const toggleHeaderRow = toSvg(
  svg`<path d="M 23.5625 0 c 1.3439 0 2.4375 1.0936 2.4375 2.4375 v 21.125 c 0 1.3439 -1.0936 2.4375 -2.4375 2.4375 H 2.4375 c -1.3439 0 -2.4375 -1.0936 -2.4375 -2.4375 V 2.4375 C 0 1.0936 1.0936 0 2.4375 0 h 21.125 Z m -5.6875 16.25 h 6.5 V 9.75 h -6.5 v 6.5 Z m 6.5 7.3125 v -5.6875 h -6.5 v 6.5 h 5.6875 c 0.4469 0 0.8125 -0.3656 0.8125 -0.8125 Z M 9.75 16.25 h 6.5 V 9.75 H 9.75 v 6.5 Z m 0 8.125 h 6.5 v -6.5 H 9.75 v 6.5 Z m -8.125 -8.125 h 6.5 V 9.75 H 1.625 v 6.5 Z m 6.5 8.125 v -6.5 H 1.625 v 5.6875 c 0 0.4469 0.3656 0.8125 0.8125 0.8125 h 5.6875 Z" fill-rule="evenodd"/>`
);
    
export const toggleHeaderCell = toSvg(
  svg``
);

export const mergeOrSplit = toSvg(
  svg`<path pid="0" d="M2 19a3 3 0 0 0 3 3h14a3 3 0 0 0 3-3V5a3 3 0 0 0-3-3H5a3 3 0 0 0-3 3v14zm-2 0V5a5 5 0 0 1 5-5h14a5 5 0 0 1 5 5v14a5 5 0 0 1-5 5H5a5 5 0 0 1-5-5zm12-9a1 1 0 0 1 1 1v2a1 1 0 0 1-2 0v-2a1 1 0 0 1 1-1zm0 6a1 1 0 0 1 1 1v3a1 1 0 0 1-2 0v-3a1 1 0 0 1 1-1zm0-13a1 1 0 0 1 1 1v3a1 1 0 0 1-2 0V4a1 1 0 0 1 1-1z"></path>`
);

export const setCellAttribute = toSvg(
  svg``
);

export const fixTables = toSvg(
  svg``
);

export const goToNextCell = toSvg(
  svg``
);
export const goToPreviousCell = toSvg(
  svg``
);
