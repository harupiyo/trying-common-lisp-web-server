function send(){
	const text = document.querySelector('[type=text]')
	say(text.value)
	return false // for not to submit
}

const submit = document.querySelector('[type=submit]')
submit.addEventListener('click', send)

const input = document.querySelector('[type=text]')
input.addEventListener('keypress', (e) => {
	console.log(e)
	if (e.keyCode == 13 ) send()
})

function genRandomId(){
	let counter = 1
	return () => {
		return 'G' + counter++
	}
}

const randomId = genRandomId()

function say(message){
	const options = { mode: 'same-origin', headers: { 'Content-Type': 'images/svg+xml' } }
	fetch( 'http://localhost:8000/api/svg?name=' + encodeURI(message), options )
	.then( response => {
		if (!response.ok) throw new Error('Fetch API: Network response was not ok')
		if ( response.headers.get('content-type') !== 'image/svg+xml' ) throw new Error('Fetch API: Allow SVG only')
		return response.blob()
	}) 
	.then( svg => {
		const container = document.querySelector('#svg-container')
		const id = randomId()
		const img = document.createElement('img')
		const br = document.createElement('br')
		img.id = id
		img.alt = message
		const reader = new FileReader()
		reader.addEventListener("load", () => {
			img.src = reader.result;
			container.appendChild(img)
			container.appendChild(br)
			location.href = "#" + id
		})
		reader.readAsDataURL(svg)
	})
}

