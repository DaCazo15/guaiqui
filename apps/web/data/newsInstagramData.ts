export interface InstagramNewsPost {
  id: string
  title: string
  badge: string
  caption: string
  image_url: string
  date_formatted: string
  timestamp: string
  category: 'playoffs' | 'roster' | 'community' | 'clasico'
  post_url?: string
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
  bio: 'Cuenta oficial de los 9 veces campeones del baloncesto venezolano. Isla de Margarita, Edo. Nueva Esparta. #LaTribuVerde',
  followers: '124K',
  posts_count: 852,
  following: 89,
  verified: true,
  avatar: '/logo.png',
  instagram_url: 'https://www.instagram.com/guaiqueriesbbc/',
}

export const newsInstagramPosts: InstagramNewsPost[] = [
  {
    id: 'spb-news-1',
    title: 'GUAIQUERÍES NO SE RINDE Y EVITA LA BARRIDA',
    badge: 'DESTACADOS',
    caption: 'Guaiqueríes de Margarita todavía sigue con opciones de llevarse el título de la temporada 2026 de la Superliga Profesional de Baloncesto (SPB), luego de vencer 81-70 a Marinos de Anzoátegui en el Gimnasio Luis Ramos del eje Barcelona-Puerto La Cruz, extendiendo la Gran Final al menos un juego más.\n\nTodo parecía una fiesta para que el Acorazado se corone frente a su público en la Caldera del Diablo, pero al frente se encontraba un equipo insular que no quería ser barrido. Marinos empezó con fuerza y se llevó el primer parcial 21-13, pero para el segundo cuarto la ofensiva de Guaiqueríes desplegó todo su poder triplero y se fue al descanso arriba 42-34.\n\nEl máximo anotador del encuentro fue Nazhiah Carter con 25 puntos, mientras que Pedro Chourio finalizó con 24 contables (8 triples de 12 intentos), igualando el récord en un juego en estas instancias.',
    image_url: '/images/noticias/noticia-spb-1.jpg',
    date_formatted: 'martes, 16 de junio del 2026',
    timestamp: '2026-06-16T20:00:00Z',
    category: 'playoffs',
    post_url: 'https://www.spbven.com/guaiqueries-no-se-rinde-y-evita-la-barrida/',
    likes_count: 3420,
    comments_count: 248,
    tags: ['#Guaiqueríes', '#SPB2026', '#GranFinal', '#NoSeRinde', '#LaTribuVerde'],
    is_verified: true,
    author: {
      username: 'guaiqueriesbbc',
      name: 'Guaiqueríes de Margarita',
      avatar: '/logo.png',
    },
  },
  {
    id: 'spb-news-2',
    title: 'GUAIQUERÍES GANÓ Y AVANZÓ A LA GRAN FINAL DE LA SPB 2026',
    badge: 'DESTACADOS',
    caption: 'Guaiqueríes de Margarita y Marinos de Anzoátegui volverán a medirse en una final tras 35 años, luego de que los dirigidos por Fernando Duró le quitaran el invicto de 17 juegos como local a Cocodrilos de Caracas, venciéndolo 86-83 en un repleto Parque Naciones Unidas, llevándose el séptimo encuentro de la serie Semifinal de la Superliga Profesional de Baloncesto (SPB) 2026.\n\nGelvis Solano contó con un partido consagratorio al sumar 30 puntos, seis rebotes y ocho asistencias, seguido de James Reese con 22 tantos y cuatro triples. ¡La Tribu está en la Gran Final!',
    image_url: '/images/noticias/noticia-spb-2.jpg',
    date_formatted: 'domingo, 07 de junio del 2026',
    timestamp: '2026-06-07T22:00:00Z',
    category: 'playoffs',
    post_url: 'https://www.spbven.com/guaiqueries-gano-y-avanzo-a-la-gran-final-de-la-spb-2026/',
    likes_count: 4890,
    comments_count: 412,
    tags: ['#GranFinalSPB', '#Guaiqueríes', '#Juego7', '#ParqueNacionesUnidas', '#OrgulloInsular'],
    is_verified: true,
    author: {
      username: 'guaiqueriesbbc',
      name: 'Guaiqueríes de Margarita',
      avatar: '/logo.png',
    },
  },
  {
    id: 'spb-news-3',
    title: 'MARINOS QUEDÓ A UN PASO, GUAIQUERÍES IGUALÓ',
    badge: 'DESTACADOS',
    caption: 'Este 1 de junio empezó el último mes de la temporada 2026 de la Superliga Profesional de Baloncesto (SPB), teniendo par de encuentros decisivos en las Semifinales. El Guaiqueríes Arena le cambió la cara totalmente al conjunto verde, que tras caer dos veces en Caracas ante Cocodrilos, empató la serie 2-2 tras imponerse contundentemente 72-57.\n\nJuan Guerrero respondió de nuevo con 19 puntos, misma cantidad que anotó Pedro Chourio. Ambos comandaron la ofensiva insular para defender la casa con máxima garra.',
    image_url: '/images/noticias/noticia-spb-3.jpg',
    date_formatted: 'martes, 02 de junio del 2026',
    timestamp: '2026-06-02T19:30:00Z',
    category: 'clasico',
    post_url: 'https://www.spbven.com/marinos-quedo-a-un-paso-guaiqueries-igualo/',
    likes_count: 2950,
    comments_count: 184,
    tags: ['#GuaiqueríesArena', '#SerieEmpatada', '#SemifinalesSPB', '#LaChoza'],
    is_verified: true,
    author: {
      username: 'guaiqueriesbbc',
      name: 'Guaiqueríes de Margarita',
      avatar: '/logo.png',
    },
  },
  {
    id: 'spb-news-4',
    title: 'GUAIQUERÍES SE IMPUSO EN “LA CHOZA”',
    badge: 'DESTACADOS',
    caption: 'Este domingo 31 de mayo se reanudó la acción de la Superliga Profesional de Baloncesto (SPB) en el Guaiqueríes Arena de Margarita, donde el conjunto local se impuso 84-69 a Cocodrilos de Caracas.\n\nCon un espectacular accionar desde la larga distancia, los insulares plasmaron superioridad desde el primer cuarto. El mejor del compromiso fue Juan Guerrero con una estelar actuación de 30 puntos y cinco rebotes, secundado por Pedro Chourio desde la banca con 19 unidades.',
    image_url: '/images/noticias/noticia-spb-4.jpg',
    date_formatted: 'domingo, 31 de mayo del 2026',
    timestamp: '2026-05-31T21:00:00Z',
    category: 'playoffs',
    post_url: 'https://www.spbven.com/guaiqueries-se-impuso-en-la-choza/',
    likes_count: 3120,
    comments_count: 195,
    tags: ['#LaChoza', '#Guaiqueríes', '#LaAsunción', '#SPB2026'],
    is_verified: true,
    author: {
      username: 'guaiqueriesbbc',
      name: 'Guaiqueríes de Margarita',
      avatar: '/logo.png',
    },
  },
  {
    id: 'spb-news-5',
    title: 'TODO LISTO PARA LA ACCIÓN DE LAS SEMIFINALES EN LA SPB 2026',
    badge: 'COCODRILOS',
    caption: 'La Superliga Profesional de Baloncesto vibrará con el inicio de las Semifinales de la temporada 2026. A partir de este miércoles 27 de mayo, cuatro de los equipos con mayor tradición se verán las caras: Cocodrilos de Caracas vs Guaiqueríes de Margarita y Gaiteros del Zulia vs Marinos de Anzoátegui.\n\nGuaiqueríes fortaleció sus filas en el Draft de Refuerzos con el perimetral James Reese V y la solidez debajo de los tableros del pívot criollo Miguel Ruiz.',
    image_url: '/images/noticias/noticia-spb-5.jpg',
    date_formatted: 'martes, 26 de mayo del 2026',
    timestamp: '2026-05-26T18:00:00Z',
    category: 'roster',
    post_url: 'https://www.spbven.com/todo-listo-para-la-accion-de-las-semifinales-en-la-spb-2026/',
    likes_count: 2240,
    comments_count: 140,
    tags: ['#SemifinalesSPB', '#DraftRefuerzos', '#BaloncestoVenezolano', '#RumboAlTítulo'],
    is_verified: true,
    author: {
      username: 'guaiqueriesbbc',
      name: 'Guaiqueríes de Margarita',
      avatar: '/logo.png',
    },
  },
  {
    id: 'spb-news-6',
    title: 'GAITEROS Y GUAIQUERÍES SELLARON SU BOLETO A SEMIFINALES',
    badge: 'DESTACADOS',
    caption: 'Este 24 de mayo se conocieron los clasificados restantes a Semifinales. En un partido vibrante en La Asunción que se definió en los segundos finales, Guaiqueríes de Margarita selló su boleto con triunfo 87-83 frente a Trotamundos de Carabobo.\n\nPedro Chourio fue el más destacado de la fecha con 30 puntos, escoltado por Gelvis Solano con 27 unidades y José Ascanio con 15 tantos. ¡La Tribu sigue en carrera por la gloria!',
    image_url: '/images/noticias/noticia-spb-6.jpg',
    date_formatted: 'domingo, 24 de mayo del 2026',
    timestamp: '2026-05-24T22:30:00Z',
    category: 'community',
    post_url: 'https://www.spbven.com/gaiteros-y-guaiqueries-sellaron-su-boleto-a-semifinales/',
    likes_count: 3670,
    comments_count: 280,
    tags: ['#Clasificados', '#Semifinales', '#LaTribuVerde', '#PedroChourio'],
    is_verified: true,
    author: {
      username: 'guaiqueriesbbc',
      name: 'Guaiqueríes de Margarita',
      avatar: '/logo.png',
    },
  },
]
