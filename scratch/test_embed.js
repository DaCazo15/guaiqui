async function test() {
  const res = await fetch('https://www.instagram.com/p/DA_5rXbM-c1/embed/');
  const html = await res.text();
  
  // Find img
  const imgMatches = [...html.matchAll(/<img[^>]+src="([^">]+)"/g)];
  console.log('Found images:', imgMatches.length);
  for (const m of imgMatches.slice(0, 5)) {
    console.log('IMG:', m[1].slice(0, 120));
  }
  
  // Find caption / text
  const descMatch = html.match(/<div class="Caption"[^>]*>([\s\S]*?)<\/div>/);
  if (descMatch) {
    console.log('Caption:', descMatch[1].replace(/<[^>]+>/g, '').trim());
  } else {
    const titleMatch = html.match(/<title>([^<]+)<\/title>/);
    console.log('Title:', titleMatch ? titleMatch[1] : 'No title');
  }
}

test();
