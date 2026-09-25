/* El estado del laboratorio (ensayo, temporizadores, logros, cuaderno y sonidos) vive en @sts/core
   y lo comparten escritorio y móvil: aquí solo se le pasan los hooks de React. */
import * as React from "react";
import { createLabHook } from "@sts/core";

export const useLab = createLabHook(React);
