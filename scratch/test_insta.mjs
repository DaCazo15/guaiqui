import fs from 'fs'

async function inspectHtml() {
  const res = await fetch('https://www.instagram.com/p/DA_5rXbM-c1/embed/captioned/', {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  })
  const html = await res.text()
  fs.writeFileSync('scratch/embed.html', html)
  console.log('Saved to scratch/embed.html')
}

inspectHtml()
