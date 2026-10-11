export interface InstagramNewsPost {
  id: string
  title: string
  caption: string
  image_url: string
  date_formatted: string
  timestamp: string
  category: 'playoffs' | 'roster' | 'community' | 'clasico'
  likes_count: number
  comments_count: number
  tags: string[]
  is_verified: boolean
  author: {
    username: string
    name: string
    avatar: string
  }
}

export const officialProfile = {
  username: 'guaiqueriesbbc',
  name: 'Guaiqueríes de Margarita',
  bio: 'Cuenta oficial de los 9 veces campeones del baloncesto venezolano 🏀 Isla de Margarita, Edo. Nueva Esparta 🌴 #LaTribuVerde',
  followers: '124K',
  posts_count: 852,
  following: 89,
  verified: true,
  avatar: '/logo.png',
  instagram_url: 'https://www.instagram.com/guaiqueriesbbc/',
}

export const newsInstagramPosts: InstagramNewsPost[] = [
  {
    id: 'news-1',
    title: '¡A la Gran Final de la SPB 2026!',
    caption: '¡NUEVA ESPARTA ESTÁ EN LA GRAN FINAL! 🏆 En un séptimo juego para la historia en el Gimnasio Ciudad de La Asunción, la Tribu se impuso con casta guerrera ante Cocodrilos de Caracas. Gracias a la mejor fanaticada del país por hacer retumbar El Fortín. ¡Vamos por la décima estrella insular!',
    image_url: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=900&auto=format&fit=crop&q=80',
    date_formatted: 'Hace 3 horas',
    timestamp: '2026-10-11T16:00:00Z',
    category: 'playoffs',
    likes_count: 3420,
    comments_count: 248,
    tags: ['#LaTribuVerde', '#SPB2026', '#GranFinal', '#ElFortín', '#Guaiqueríes'],
    is_verified: true,
    author: {
      username: 'guaiqueriesbbc',
      name: 'Guaiqueríes de Margarita',
      avatar: '/logo.png',
    },
  },
  {
    id: 'news-2',
    title: 'Remontada épica de la Tribu',
    caption: '¡JAMÁS NOS DEN POR MUERTOS! Tras caer 0-2 en la serie, el equipo sacó el corazón insular y remontó ante un rival durísimo. Cada balón suelto se peleó como si fuera el último. ¡Esto es Guaiqueríes, orgullo del estado Nueva Esparta!',
    image_url: 'https://images.unsplash.com/photo-1504450758481-7338eba7524a?w=900&auto=format&fit=crop&q=80',
    date_formatted: 'Ayer',
    timestamp: '2026-10-10T20:30:00Z',
    category: 'playoffs',
    likes_count: 2890,
    comments_count: 174,
    tags: ['#Remontada', '#PlayoffsSPB', '#GuaiqueríesDeMargarita', '#OrgulloInsular'],
    is_verified: true,
    author: {
      username: 'guaiqueriesbbc',
      name: 'Guaiqueríes de Margarita',
      avatar: '/logo.png',
    },
  },
  {
    id: 'news-3',
    title: 'Juan Guerrero se incorpora a la Tribu',
    caption: 'OFICIAL 🚨 El pívot dominicano Juan Guerrero ya viste los colores verde y oro de Guaiqueríes de Margarita. Fuerza, presencia en la pintura y veteranía internacional para encarar la recta decisiva de la temporada. ¡Bienvenido a tu nueva casa!',
    image_url: 'https://images.unsplash.com/photo-1519861531473-9200262188bf?w=900&auto=format&fit=crop&q=80',
    date_formatted: 'Hace 3 días',
    timestamp: '2026-10-08T14:15:00Z',
    category: 'roster',
    likes_count: 1980,
    comments_count: 92,
    tags: ['#FichajeOficial', '#Refuerzo', '#SPB', '#LaTribuSeBlinda'],
    is_verified: true,
    author: {
      username: 'guaiqueriesbbc',
      name: 'Guaiqueríes de Margarita',
      avatar: '/logo.png',
    },
  },
  {
    id: 'news-4',
    title: 'Clásico Oriental vibrante en la Gran Final',
    caption: 'Se enciende la rivalidad más apasionante del deporte venezolano: Guaiqueríes de Margarita vs Marinos de Anzoátegui en la Gran Final de la SPB. Una batalla donde se juega el honor y la supremacía de todo el oriente del país.',
    image_url: 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=900&auto=format&fit=crop&q=80',
    date_formatted: 'Hace 4 días',
    timestamp: '2026-10-07T18:45:00Z',
    category: 'clasico',
    likes_count: 4150,
    comments_count: 380,
    tags: ['#ClásicoOriental', '#GuaiqueríesVsMarinos', '#SPBFinal', '#VenezuelaBasket'],
    is_verified: true,
    author: {
      username: 'guaiqueriesbbc',
      name: 'Guaiqueríes de Margarita',
      avatar: '/logo.png',
    },
  },
  {
    id: 'news-5',
    title: 'Entrenamiento a casa llena en La Asunción',
    caption: 'La comunión entre fanaticada y jugadores es inquebrantable. Más de dos mil fanáticos se acercaron hoy al Guaiqueríes Arena para el entrenamiento abierto al público. ¡Ustedes son el sexto hombre en cancha!',
    image_url: 'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?w=900&auto=format&fit=crop&q=80',
    date_formatted: 'Hace 5 días',
    timestamp: '2026-10-06T11:20:00Z',
    category: 'community',
    likes_count: 1650,
    comments_count: 81,
    tags: ['#ComunidadVerde', '#LaAsunción', '#FanáticosGuaiqueríes', '#Margarita'],
    is_verified: true,
    author: {
      username: 'guaiqueriesbbc',
      name: 'Guaiqueríes de Margarita',
      avatar: '/logo.png',
    },
  },
  {
    id: 'news-6',
    title: 'Golpe de autoridad en Puerto La Cruz',
    caption: '¡VICTORIA MONUMENTAL! La Tribu Verde silenció el Luis Ramos con una cátedra defensiva y un cierre implacable. La serie se traslada ahora a nuestra isla para definir el campeonato ante nuestra gente.',
    image_url: 'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=900&auto=format&fit=crop&q=80',
    date_formatted: 'Hace 1 semana',
    timestamp: '2026-10-04T22:10:00Z',
    category: 'clasico',
    likes_count: 3780,
    comments_count: 265,
    tags: ['#VictoriaGuaiquerí', '#SPB', '#PasoFirme', '#RumboAlTítulo'],
    is_verified: true,
    author: {
      username: 'guaiqueriesbbc',
      name: 'Guaiqueríes de Margarita',
      avatar: '/logo.png',
    },
  },
]
