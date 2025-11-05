import { QuartzComponent, QuartzComponentConstructor } from "./types"

export const CustomFooter: QuartzComponentConstructor = () => {
  return ({}) => (
    <footer>
      <p>© 2025 Axel Bux. Все права защищены.</p>
      <ul>
        <li><a href="https://t.me/axelbux">Мой Telegram</a></li>
        <li><a href="https://vk.com/axelbux">Мой VK (Вконтакте)</a></li>   
      </ul>
    </footer>
  )
}