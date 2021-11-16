function send(){
	const text = document.querySelector('[type=text]');
	say(text.value);
	return false; // for not to submit
}

const submit = document.querySelector('[type=submit]');
submit.addEventListener('click', send);

const input = document.querySelector('[type=text]');
input.addEventListener('keypress', (e) => {
	console.log(e)
	if (e.keyCode == 13 ) send()
});

function genRandomId(){
	let counter = 1
	return () => {
		return 'G' + counter++
	}
}

let randomId = genRandomId()

function say(message){
	const options = { mode: 'same-origin', headers: { 'Content-Type': 'images/svg+xml' } }
	fetch( 'http://localhost:8000/api/svg?name=' + encodeURI(message), options )
		.then( response => {
			if (!response.ok) throw new Error('Fetch API: Network response was not ok')
			if ( response.headers.get('content-type') !== 'image/svg+xml' ) throw new Error('Fetch API: Allow SVG only')
			return response.text()
		}) 
		.then( svg => {
			let id = randomId()
			let img = document.createElement ('img')
			img.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svg)))
			img.id = id
			let container = document.querySelector('#svg-container')
			container.appendChild(img)
			let br = document.createElement ('br')
			container.appendChild(br)
			location.href = "#" + id
		})
}

