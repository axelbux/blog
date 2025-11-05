import { QuartzComponent, QuartzComponentConstructor } from "./types"

export const CustomHead: QuartzComponentConstructor = () => {
  return () => (
    <>
      <style>{`
        /* Увеличить отступы между пунктами списка */
        ul li,
        ol li {
          margin-bottom: 0.8em !important;
        }

        /* Отступы в проводнике (левое меню) */
        .explorer-ul li {
          margin: 0.3rem 0 !important;
        }

        /* Дополнительно: отступы между параграфами */
        article p {
          margin-bottom: 1.2em;
        }
      `}</style>
    </>
  )
}