# Guía de GSAP: efectos paso a paso y animaciones que rompen la monotonía

*Oct 26, 2026 · @Daniel Cazorla*

GSAP v3.15 cubre desde un fade hasta scroll pinneado, texto por líneas y transiciones de layout; esta guía recorre cada herramienta con código y termina con recetas propias inspiradas en fanxp.digital.

---

## 1. Preparación

El núcleo de GSAP trae tweens, timelines, easing y staggers; los efectos grandes (scroll, texto, layout) viven en plugins que se registran una vez. La [página de instalación](https://gsap.com/docs/v3/Installation) tiene un asistente con el código exacto; confirma ahí la licencia vigente de los plugins.

```bash
npm install gsap
```

```javascript
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { SplitText } from "gsap/SplitText";
import { Flip } from "gsap/Flip";

gsap.registerPlugin(ScrollTrigger, SplitText, Flip);
```

> **Importante:** Registrar el plugin también lo protege del tree shaking: si funciona en desarrollo y falla en producción, casi siempre falta el `registerPlugin`.

### Uso en Vue 3

Crea las animaciones dentro de `gsap.context()` con el elemento raíz como alcance y revierte al desmontar; así los selectores quedan limitados al componente y no quedan ScrollTriggers huérfanos.

```vue
<script setup>
import { ref, onMounted, onBeforeUnmount } from "vue";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";

gsap.registerPlugin(ScrollTrigger);

const root = ref(null);
let ctx;

onMounted(() => {
  ctx = gsap.context(() => {
    gsap.from(".card", {
      autoAlpha: 0,
      y: 40,
      stagger: 0.1,
      scrollTrigger: {
        trigger: ".card",
        start: "top 85%"
      }
    });
  }, root.value);
});

onBeforeUnmount(() => ctx && ctx.revert());
</script>
```

---

## 2. Fundamentos

Un tween es un asignador de propiedades de alto rendimiento: le das objetivos, duración y valores, y calcula cada fotograma. Hay tres formas de crearlo: `gsap.to()`, `gsap.from()` y `gsap.fromTo()`. Un timeline agrupa tweens y permite controlarlos como un bloque.

### Paso a paso

Anima algo simple. `x` e `y` son atajos de transform; la duración por defecto es 0,5 s y el ease por defecto es `power1.out`.

```javascript
gsap.to(".box", { x: 100, rotation: 27, duration: 1 });
```

Guarda el tween en una variable para controlarlo: `pause()`, `play()`, `reverse()`, `seek()`, `progress()`, `timeScale()`.

```javascript
const t = gsap.to(".box", { rotation: 360, duration: 5, ease: "elastic" });
t.pause();
t.progress(0.5);
t.play();
```

Escalona varios elementos con `stagger`. Un número es el retardo entre inicios; un objeto permite `each`, `amount`, `from` ("center", "edges", "random", "end" o un índice), `grid`, `axis` y `ease`.

```javascript
gsap.from(".item", {
  autoAlpha: 0,
  y: 30,
  stagger: {
    each: 0.08,
    from: "center",
    grid: "auto",
    ease: "power2.inOut"
  }
});
```

Usa valores dinámicos: funciones `(index, target, targets)`, aleatorios `"random(-100, 100, 5)"` y relativos `"+=20"`.

```javascript
gsap.to(".dot", {
  x: "random(-200, 200)",
  y: (i) => i * 20,
  repeat: -1,
  repeatRefresh: true
});
```

Encadena con un timeline y el parámetro de posición, que decide dónde entra cada animación: número absoluto, `"+=1"` (hueco), `"-=0.5"` (solapa), una etiqueta, `"<"` (inicio de la anterior) y `">"` (final de la anterior).

```javascript
const tl = gsap.timeline({ defaults: { duration: 0.8, ease: "power3.out" } });
tl.from(".title", { y: 60, autoAlpha: 0 })
  .from(".subtitle", { y: 30, autoAlpha: 0 }, "<0.2") // 0,2 s tras empezar el título
  .from(".cta", { scale: 0.8, autoAlpha: 0 }, "-=0.3") // solapa 0,3 s
  .addLabel("done");
```

Varios estados en un solo elemento: `keyframes` (solo en `to()`).

```javascript
gsap.to(".ball", {
  keyframes: [
    { x: 100, duration: 1 },
    { y: 100, duration: 0.5 }
  ]
});
```

*Novedad de la versión 3.15:* `easeReverse` aplica un ease propio cuando la animación se invierte, útil en hovers que entran y salen con curvas distintas (`easeReverse: true` repite el mismo ease; también acepta otro como `"back.out"`).

### Easings

Familias del núcleo: `none`, `power1`–`power4`, `back`, `bounce`, `circ`, `elastic`, `expo`, `sine` y `steps(n)`, cada una con `.in`, `.out` o `.inOut`. El [Ease Visualizer](https://gsap.com/docs/v3/Eases) permite verlas y dibujar la tuya (ver CustomEase en la sección 3).

---

## 3. Catálogo de efectos, uno por uno

### ScrollTrigger: animar según el scroll

Vincula una animación a la posición del scroll. `start` y `end` describen dos puntos: «lugar del trigger + lugar del viewport», por ejemplo `"top 80%"`.

#### Revelar al entrar (se ejecuta una vez):

```javascript
gsap.from(".card", {
  y: 60,
  autoAlpha: 0,
  scrollTrigger: { trigger: ".card", start: "top 85%", once: true }
});
```

#### Scrub: la animación avanza con la barra.
`scrub: 1` tarda 1 s en «alcanzarla» y suaviza el movimiento.

```javascript
gsap.to(".hero-img", {
  scale: 1.4,
  ease: "none",
  scrollTrigger: {
    trigger: ".hero",
    start: "top top",
    end: "bottom top",
    scrub: 1
  }
});
```

#### Pin: congela un elemento mientras dura el scroll.
Anima solo lo que hay dentro del elemento fijado, nunca el propio pin.

```javascript
const tl = gsap.timeline({
  scrollTrigger: {
    trigger: ".steps",
    pin: true,
    start: "top top",
    end: "+=2000",
    scrub: 1,
    snap: {
      snapTo: "labels",
      duration: { min: 0.2, max: 1 },
      ease: "power1.inOut"
    }
  }
});
tl.addLabel("uno").from(".s1", { autoAlpha: 0 })
  .addLabel("dos").from(".s2", { autoAlpha: 0 })
  .addLabel("tres");
```

#### Scroll horizontal movido por scroll vertical, con containerAnimation para disparar cosas dentro (el ease del contenedor debe ser "none"):

```javascript
const panels = gsap.utils.toArray(".panel");
const move = gsap.to(panels, {
  xPercent: -100 * (panels.length - 1),
  ease: "none",
  scrollTrigger: {
    trigger: ".track",
    pin: true,
    scrub: 1,
    end: () => "+=" + document.querySelector(".track").offsetWidth
  }
});

gsap.from(".panel-3 h2", {
  y: 80,
  autoAlpha: 0,
  scrollTrigger: {
    trigger: ".panel-3",
    containerAnimation: move,
    start: "left center"
  }
});
```

#### Grupos que entran juntos con `ScrollTrigger.batch()`, que entrega los elementos de cada tanda como arreglo:

```javascript
gsap.set(".card", { autoAlpha: 0, y: 50 });
ScrollTrigger.batch(".card", {
  start: "top 85%",
  onEnter: (els) => gsap.to(els, { autoAlpha: 1, y: 0, stagger: 0.1, overwrite: true })
});
```

Durante el desarrollo activa `markers: true` para ver los puntos de inicio y fin. Si no necesitas animar nada, `ScrollTrigger.create()` ofrece solo callbacks (`onEnter`, `onLeave`, `onToggle`, `onUpdate`) y datos como `self.progress`, `self.direction` y `self.getVelocity()`.

---

### SplitText: texto por líneas, palabras y letras

Divide un elemento en `lines`, `words` y `chars`, y añade `aria-label` para lectores de pantalla. Con `autoSplit: true` vuelve a dividir cuando cargan las fuentes o cambia el ancho; por eso la animación va dentro de `onSplit()` y se devuelve.

#### Revelado por líneas con máscara (cada línea sube desde un recorte):

```javascript
SplitText.create(".reveal", {
  type: "lines",
  mask: "lines",
  autoSplit: true,
  onSplit(self) {
    return gsap.from(self.lines, {
      yPercent: 110,
      duration: 1,
      ease: "power4.out",
      stagger: 0.08,
      scrollTrigger: {
        trigger: ".reveal",
        start: "top 80%"
      }
    });
  }
});
```

#### Texto que se «ilumina» palabra a palabra con el scroll:

```javascript
SplitText.create(".manifesto", {
  type: "words",
  onSplit(self) {
    return gsap.fromTo(self.words,
      { opacity: 0.15 },
      {
        opacity: 1,
        stagger: 0.05,
        ease: "none",
        scrollTrigger: {
          trigger: ".manifesto",
          start: "top 75%",
          end: "bottom 40%",
          scrub: true
        }
      }
    );
  }
});
```

> **Consejo:** Divide solo lo que animes: separar miles de letras es caro. Si divides solo por `chars`, activa `smartWrap: true` para que las palabras no se corten a mitad. Evita `text-wrap: balance` y, si ves letras que se desplazan, usa `font-kerning: none`.

---

### ScrollSmoother: scroll suave y parallax

Usa scroll nativo (sin barra falsa) y se construye sobre ScrollTrigger. Necesita un envoltorio y un contenido; lo que lleve `position: fixed` va fuera.

```html
<div id="smooth-wrapper">
  <div id="smooth-content">
    <img data-speed="auto" src="hero.jpg" /> <!-- parallax según el espacio que tenga -->
    <h2 data-speed="0.8">Se mueve al 80 %</h2>
    <div class="card" data-lag="0.4">Llega 0,4 s tarde</div>
  </div>
</div>
```

```javascript
gsap.registerPlugin(ScrollTrigger, ScrollSmoother);
ScrollSmoother.create({
  smooth: 1,
  effects: true
}); // créalo antes que tus ScrollTriggers
```

Con `data-speed="clamp(0.5)"` los elementos de la parte superior de la página no empiezan desplazados. Para detener todo el scroll (por ejemplo, con un modal) usa `smoother.paused(true)`.

---

### Flip: transiciones entre dos estados del DOM

Flip registra posición y tamaño, tú cambias el DOM y Flip anima la diferencia. Es la herramienta para reordenar, filtrar o expandir elementos sin que «salten».

1. `Flip.getState()` antes del cambio.
2. Cambia clases o mueve nodos.
3. `Flip.from(state)`.

```javascript
const state = Flip.getState(".card");
card.classList.toggle("is-open"); // o reordena / filtra nodos
Flip.from(state, { duration: 0.8, ease: "power3.inOut", absolute: true });
```

Para cruzar dos elementos distintos dales el mismo `data-flip-id` y usa `fade: true`. Con `onEnter` y `onLeave` animas lo que aparece o desaparece. En Vue espera al render (`await nextTick()`) antes de llamar a `Flip.from()` y pasa targets si el framework recrea los nodos.

---

### Observer: gestos sin scroll real

Unifica rueda, touch y puntero con dirección y velocidad. Sirve para secciones tipo «pantalla completa» que cambian por gesto.

```javascript
let i = 0, busy = false;
const go = (n) => {
  if (busy || n < 0 || n >= sections.length) return;
  busy = true;
  i = n;
  gsap.to(wrapper, {
    yPercent: -100 * i,
    duration: 1,
    ease: "power3.inOut",
    onComplete: () => (busy = false)
  });
};

Observer.create({
  type: "wheel,touch,pointer",
  wheelSpeed: -1,
  tolerance: 10,
  preventDefault: true,
  onUp: () => go(i + 1),
  onDown: () => go(i - 1)
});
```

---

### SVG: DrawSVG y MotionPath

DrawSVG revela el trazo; el valor describe el estado final como segmento (`"20% 80%"`) y puede crecer desde el centro (`"50% 50%"` hasta `"0% 100%"`). El elemento necesita `stroke` definido.

```javascript
gsap.from(".draw-me", { drawSVG: 0, duration: 1, stagger: 0.1 });
gsap.fromTo("#linea", { drawSVG: "50% 50%" }, { drawSVG: "0% 100%", duration: 1.2 });
```

MotionPath mueve cualquier elemento por un trazado SVG, con rotación automática y alineación:

```javascript
gsap.to("#balon", {
  motionPath: {
    path: "#ruta",
    align: "#ruta",
    alignOrigin: [0.5, 0.5],
    autoRotate: true
  },
  transformOrigin: "50% 50%",
  duration: 5,
  ease: "power1.inOut"
});
```

---

### ScrambleText: decodificar texto

```javascript
gsap.to(".label", {
  duration: 1.2,
  scrambleText: { text: "FAN BASE", chars: "XO", revealDelay: 0.3, speed: 0.4 }
});
```

---

### CustomEase: tus propias curvas

Dibuja la curva en el Ease Visualizer, copia el trazado SVG (o un cubic-bezier de cuatro números) y regístrala con un nombre propio, distinto de los eases estándar.

```javascript
gsap.registerPlugin(CustomEase);
CustomEase.create("hop", "M0,0 C0,0 0.056,0.442 0.175,0.442 0.294,0.442 0.332,0 0.332,0 0.332,0 0.414,1 0.671,1 0.991,1 1,0 1,0");
CustomEase.create("suave", ".76,0,.24,1");
gsap.to(".logo", { y: -100, duration: 1, ease: "hop" });
```

---

### Otros plugins útiles

| Plugin | Para qué sirve |
| :--- | :--- |
| **Draggable + Inertia** | Arrastrar con inercia (carruseles, tarjetas). |
| **MorphSVG** | Transformar una forma SVG en otra. |
| **ScrollTo** | Navegar suavemente a anclas y secciones. |
| **TextPlugin** | Reemplazar el texto de un elemento durante la animación. |
| **Physics2D** | Movimiento con gravedad y velocidad (confeti, partículas). |
| **GSDevTools** | Barra para reproducir y depurar timelines. |

---

## 4. Qué se ve en fanxp.digital

Al abrir [fanxp.digital](https://www.fanxp.digital/) solo pude leer su estructura y contenido; no pude ver las animaciones ni su código. Las imágenes cargan desde `cdn.prod.website-files.com`, lo que indica que el sitio está hecho en Webflow. La columna «técnica probable» es mi inferencia a partir de esa estructura, no algo verificado en su código; para confirmarlo abre las DevTools del sitio y revisa qué librería registra cada efecto.

| Bloque del sitio | Qué contiene | Técnica probable en GSAP |
| :--- | :--- | :--- |
| **Hero «Fans First, Always.»** | Título grande y una tira de imágenes que se repite (el mismo juego de cinco imágenes aparece tres veces) | Entrada con SplitText y marquee infinito con `xPercent` y `repeat: -1` |
| **«Datos que existen. Valor que no se captura.»** | Tres tarjetas de problema con imágenes alternadas | Revelado por `ScrollTrigger.batch()` y parallax de imágenes |
| **«DATA ACTUAL» frente a «CON FXP»** | Dos listas de campos de datos; la segunda es mucho más larga | Stagger desde distintos orígenes: la lista nueva «se llena» |
| **«Todo empieza con el fan»** | Cuatro pasos numerados: Integración, Perfilado, Activación, Monetización | Pin + scrub con timeline y etiquetas, un paso por tramo de scroll |
| **Soluciones** | Cinco módulos: Fan Base, Fan Engagement, Data Connect, Analytics, Loyalty Program | Tarjetas que cambian por hover o scroll, posible Flip |
| **Cifras** | +300 % fanbase, +8M interacciones, +2,2M fans unificados | Contadores con snap al entrar en pantalla |
| **Cierre** | Blog, formulario y demo | Transiciones de entrada sencillas |

La lección de diseño es que el sitio cuenta una historia en este orden: problema, datos dispersos, ecosistema, proceso en cuatro pasos y resultados. Cada tramo tiene un movimiento distinto (tira que corre, listas que se llenan, pasos que se encadenan, números que suben); esa variedad es lo que evita la monotonía, y la sección siguiente la convierte en recetas.

---

## 5. Efectos personalizados que rompen la monotonía

El patrón común: combina dos o tres herramientas del catálogo y cambia una variable inesperada (velocidad, origen del stagger, curva). Cada receta es independiente.

### Receta 1. Marquee que se acelera con el scroll
Duplica el contenido de la tira (dos copias idénticas), desplázala -50 % en bucle y sube su `timeScale` según la velocidad del scroll. Solo se acelera, no se invierte, porque un tween con repetición infinita no retrocede de forma fiable más allá de su inicio.

```javascript
const loop = gsap.to(".marquee__inner", {
  xPercent: -50,
  ease: "none",
  duration: 20,
  repeat: -1
});

ScrollTrigger.create({
  onUpdate(self) {
    const boost = gsap.utils.clamp(1, 5, 1 + Math.abs(self.getVelocity()) / 500);
    loop.timeScale(boost); // acelera de golpe
    gsap.to(loop, { timeScale: 1, duration: 0.8, overwrite: true }); // vuelve al ritmo normal
  }
});
```

### Receta 2. Cifras que suben al entrar en pantalla
Para «+300 %», «+8M» o «+2,2M»: anima un objeto auxiliar, redondea con `snap` y escribe el texto en `onUpdate`.

```javascript
document.querySelectorAll("[data-count]").forEach((el) => {
  const o = { v: 0 };
  gsap.to(o, {
    v: parseFloat(el.dataset.count),
    duration: 2,
    ease: "power2.out",
    snap: { v: 1 },
    scrollTrigger: { trigger: el, start: "top 85%", once: true },
    onUpdate: () => (el.textContent = "+" + o.v + (el.dataset.suffix || ""))
  });
});
```

### Receta 3. Pasos 1 → 4 fijados con snap a cada paso
Una sección que se queda quieta mientras el scroll recorre los pasos; al soltar, salta al paso más cercano.

```javascript
const steps = gsap.utils.toArray(".step");
const tl = gsap.timeline({
  scrollTrigger: {
    trigger: ".process",
    pin: true,
    scrub: 1,
    end: "+=3000",
    snap: {
      snapTo: "labels",
      duration: { min: 0.2, max: 0.8 },
      ease: "power1.inOut"
    }
  }
});

steps.forEach((s, i) => {
  tl.addLabel("p" + i)
    .fromTo(s, { autoAlpha: 0, y: 60 }, { autoAlpha: 1, y: 0, duration: 1 })
    .to(steps[i - 1] || {}, { autoAlpha: 0.2, duration: 1 }, "<"); // atenúa el paso anterior
});
tl.addLabel("fin");
```

### Receta 4. Datos que convergen en un perfil
La idea de «DATA ACTUAL → CON FXP» sin copiarla: etiquetas dispersas que vuelan hasta su sitio, empezando por un punto aleatorio.

```javascript
gsap.from(".chip", {
  x: "random(-300, 300)",
  y: "random(-200, 200)",
  rotation: "random(-40, 40)",
  autoAlpha: 0,
  duration: 1.2,
  ease: "expo.out",
  stagger: { each: 0.05, from: "random" },
  scrollTrigger: { trigger: ".chips", start: "top 70%" }
});
```

### Receta 5. Tarjeta que se expande a pantalla completa (Flip)

```javascript
cards.forEach((card) =>
  card.addEventListener("click", () => {
    const state = Flip.getState(".card", { props: "borderRadius" });
    card.classList.toggle("is-open"); // en CSS: position fixed; inset: 0; border-radius: 0
    Flip.from(state, {
      duration: 0.9,
      ease: "power3.inOut",
      absolute: true,
      zIndex: 10,
      nested: true
    });
  })
);
```

### Receta 6. Cursor con inercia (quickTo)

`gsap.quickTo()` crea una función reutilizable que mueve una propiedad sin crear un tween nuevo en cada evento; es la forma eficiente de seguir el mouse.

```javascript
const xTo = gsap.quickTo(".cursor", "x", { duration: 0.4, ease: "power3" });
const yTo = gsap.quickTo(".cursor", "y", { duration: 0.4, ease: "power3" });
window.addEventListener("mousemove", (e) => {
  xTo(e.clientX);
  yTo(e.clientY);
});
```

### Receta 7. Un ritmo propio con CustomEase y stagger en cuadrícula

Un mismo movimiento se siente distinto según su curva. Registra una curva con carácter y reparte las entradas desde el centro de una cuadrícula.

```javascript
CustomEase.create("entrada", ".16,1,.3,1");
gsap.from(".tile", {
  scale: 0,
  autoAlpha: 0,
  duration: 1,
  ease: "entrada",
  stagger: { amount: 1, from: "center", grid: "auto" },
  scrollTrigger: { trigger: ".tiles", start: "top 75%" }
});
```

### Receta 8. Tu propio efecto reutilizable

`gsap.registerEffect()` convierte una receta en una función con valores por defecto, usable con `gsap.effects` o directamente en un timeline.

```javascript
gsap.registerEffect({
  name: "subir",
  defaults: { y: 50, duration: 0.9, ease: "power3.out", stagger: 0.08 },
  effect: (targets, cfg) =>
    gsap.from(targets, {
      autoAlpha: 0,
      y: cfg.y,
      duration: cfg.duration,
      ease: cfg.ease,
      stagger: cfg.stagger
    }),
  extendTimeline: true
});

gsap.effects.subir(".card");
gsap.timeline().subir(".title", { y: 80 }).subir(".card", { stagger: 0.15 }, "-=0.4");
```

---

### Reglas para que nada se vea repetido

* Cambia el origen del stagger entre secciones: `"start"`, `"center"`, `"edges"`, `"random"`.
* Alterna direcciones y distancias; no uses el mismo `y: 40` en todo el sitio.
* Usa dos o tres eases en total y que cada uno tenga una función (entrada, salida, énfasis).
* Solapa con `"<"` y `"-=0.3"` en lugar de encadenar todo en fila.
* Reserva el efecto más llamativo para un solo momento; si todo destaca, nada destaca.
* Ata al menos un movimiento a una señal del usuario (velocidad del scroll, posición del mouse).

---

## 6. Rendimiento, accesibilidad y errores comunes

### Respeta prefers-reduced-motion

`gsap.matchMedia()` ejecuta tu código solo cuando una condición se cumple y revierte todo automáticamente cuando deja de cumplirse. Sirve tanto para móvil/escritorio como para movimiento reducido.

```javascript
const mm = gsap.matchMedia();
mm.add({
  desktop: "(min-width: 800px)",
  reduce: "(prefers-reduced-motion: reduce)"
}, (ctx) => {
  const { desktop, reduce } = ctx.conditions;
  gsap.from(".card", {
    y: reduce ? 0 : desktop ? 80 : 40,
    autoAlpha: 0,
    duration: reduce ? 0 : 0.9
  });
});
```

> **Nota:** No necesitas `gsap.context()` si usas `matchMedia()`, porque ya crea uno internamente.

### Lista de comprobación

1. **Crea los ScrollTriggers en el orden en que aparecen en la página** (de arriba abajo); si no, el pin de uno desplaza mal a los de abajo (`ScrollTrigger.sort()` lo corrige).
2. **No animes el elemento fijado con pin**; anima sus hijos.
3. **Un ancestro con transform o will-change rompe el `position: fixed` del pin**; evítalo o usa `pinReparent: true` como último recurso.
4. **Evita `content-visibility: auto`** en secciones con ScrollTrigger, porque impide medir posiciones.
5. **Anima transform y opacity** (`x`, `y`, `scale`, `autoAlpha`) antes que `width`, `top` o `left`.
6. Con `SplitText` divide solo lo que animas, revierte con `revert()` al terminar y mantén `aria` en `"auto"` (o `"none"` con una copia oculta si el texto lleva enlaces).
7. Si tu framework recrea nodos, llama a `ScrollTrigger.refresh()` después del render y revierte el contexto al desmontar.
8. Con una carga lenta de fuentes o imágenes, `ScrollTrigger.refresh()` recalcula posiciones.
9. Usa `markers: true` solo en desarrollo.

---

## 7. Fuentes

Consultadas el 26 de octubre de 2026 (documentación de GSAP v3.15):
* [Documentación de GSAP v3: portada](https://gsap.com/docs/v3/)
* [Tween](https://gsap.com/docs/v3/GSAP/Tween)
* [Timeline](https://gsap.com/docs/v3/GSAP/Timeline)
* [ScrollTrigger](https://gsap.com/docs/v3/Plugins/ScrollTrigger/)
* [SplitText](https://gsap.com/docs/v3/Plugins/SplitText/)
* [ScrollSmoother](https://gsap.com/docs/v3/Plugins/ScrollSmoother/)
* [Flip](https://gsap.com/docs/v3/Plugins/Flip/)
* [Observer](https://gsap.com/docs/v3/Plugins/Observer/)
* [CustomEase](https://gsap.com/docs/v3/Eases/CustomEase)
* [DrawSVG](https://gsap.com/docs/v3/Plugins/DrawSVGPlugin)
* [MotionPath](https://gsap.com/docs/v3/Plugins/MotionPathPlugin)
* [ScrambleText](https://gsap.com/docs/v3/Plugins/ScrambleTextPlugin)
* [Staggers](https://gsap.com/resources/getting-started/Staggers)
* [gsap.matchMedia()](https://gsap.com/docs/v3/GSAP/gsap.matchMedia%28%29)
* [FXP | Fan Experience Platform](https://www.fanxp.digital/) (solo estructura y contenido; no se vieron las animaciones)
