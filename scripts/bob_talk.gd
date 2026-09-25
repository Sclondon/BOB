extends RefCounted
## Bob's conversation brain. Plain keyword matching - no AI, just vibes.
## reply() returns {"text": String, "action": String, "fun": float}.

const GREETINGS := [
	"Hi!! Hi hi hi.",
	"Hey, it's you! My favorite person.",
	"Hello! Welcome to my room.",
	"Oh hey! I was just standing here. Like I do.",
]
const FAREWELLS := [
	"Bye! Come back soon, okay?",
	"Aww, leaving already?",
	"See you later! I'll be right here. Standing.",
]
const JOKES := [
	"Why did the stick figure go to art school? To draw some conclusions!",
	"I'd tell you a joke about paper, but it's tearable.",
	"What do you call a stick figure with no legs? Still Bob. I'd still be Bob.",
	"Why don't skeletons fight? No guts. Same, honestly.",
	"I'm reading a book on anti-gravity. I can't put it down!",
	"What did one pencil say to the other? You're looking sharp!",
]
const NICE_REPLIES := [
	"Aww, stop it! ...No, keep going.",
	"You're the best! I'd hug you if my arms were longer.",
	"That makes my whole circle-head happy.",
	"Right back at you, friend!",
]
const HURT_REPLIES := [
	"Hey... that's not very nice.",
	"Wow. Okay. I'm just going to stand over here.",
	"Rude! I have feelings. Somewhere in these lines.",
]
const QUESTION_REPLIES := [
	"Hmm... maybe?",
	"I'm a stick figure, I don't know!",
	"Great question. I have no idea.",
	"Ask me again after a snack.",
	"Probably yes. Or no. One of those.",
]
const FALLBACKS := [
	"Huh. Interesting.",
	"Cool cool cool.",
	"I don't get it, but I like that you're talking to me.",
	"Mhm, mhm. Totally.",
	"Tell me more!",
	"Wow.",
	"I'll think about that.",
]
const RANDOM_THOUGHTS := [
	"Being a stick figure is pretty great, honestly.",
	"I wonder what's outside that window.",
	"Do you ever think about lines? I'm made of them.",
	"La la la~",
	"I like this room.",
	"I tried to draw myself once. It was just lines.",
	"What's your favorite food? Mine's pizza.",
	"I'm glad you're here.",
	"Sometimes I forget I don't have fingers.",
	"If I turn sideways, do I disappear?",
	"Hmm hmm hmm...",
	"I had a dream I was a circle.",
	"Is it just me, or is that clock judging me?",
	"You can pick me up, you know. Just saying.",
]


static func reply(message: String) -> Dictionary:
	var m := _normalize(message)
	if m.strip_edges().is_empty():
		return _r("...you okay there?")

	# Commands
	if _has(m, ["dance", "boogie", "groove"]):
		return _r(["You want moves? I've got moves!", "Dance party!", "Watch these noodle legs go!"].pick_random(), "dance")
	if _has(m, ["jump", "hop"]):
		return _r(["Boing!", "How high? This high!", "Hup!"].pick_random(), "jump")
	if _has(m, ["wave"]):
		return _r("Hiiii! *waves*", "wave")
	if _has(m, ["come here", "come", "over here"]):
		return _r("Coming!", "come")

	# Conversation
	if _has(m, ["how are you", "how r u", "how do you feel", "are you ok", "you ok", "hows it going", "how is it going", "whats up", "sup"]):
		return _r(how_am_i())
	if _has(m, ["hello", "hi", "hey", "hiya", "yo", "howdy", "greetings"]):
		return _r(GREETINGS.pick_random())
	if _has(m, ["bye", "goodbye", "goodnight", "see you", "see ya", "cya", "later"]):
		return _r(FAREWELLS.pick_random())
	if _has(m, ["your name", "who are you", "name"]):
		return _r("I'm Bob! Just Bob. B-O-B. Same forwards and backwards.")
	if _has(m, ["what are you", "stick", "figure", "stickman"]):
		return _r("I'm a stick figure. Mostly lines, one circle. Very efficient.")
	if _has(m, ["joke", "jokes", "funny", "laugh"]):
		return _r(JOKES.pick_random(), "", 4.0)
	if _has(m, ["love", "like you", "best friend", "cute", "cool", "awesome", "good boy", "nice", "amazing"]):
		return _r(NICE_REPLIES.pick_random(), "", 6.0)
	if _has(m, ["stupid", "dumb", "hate", "ugly", "idiot", "shut up", "loser", "boring"]):
		return _r(HURT_REPLIES.pick_random(), "", -8.0)
	if _has(m, ["hungry", "food", "eat", "hunger", "snack", "pizza"]):
		return _r(_hunger_status())
	if _has(m, ["sleep", "sleepy", "tired", "nap", "bed"]):
		return _r(_energy_status())
	if _has(m, ["smell", "stink", "stinky", "shower", "bath", "clean", "dirty"]):
		return _r(_hygiene_status())
	if _has(m, ["play", "bored", "game", "fun"]):
		return _r(_fun_status())
	if _has(m, ["thank", "thanks", "thx", "ty"]):
		return _r(["You're welcome!", "Anytime!", "No problem!"].pick_random())
	if _has(m, ["how old", "age", "birthday"]):
		return _r("I've been around for %s. Time flies when you're made of lines." % PetState.together_text())
	if _has(m, ["sing", "song"]):
		return _r("La la laaa~ ...I don't know the words.", "", 3.0)
	if _has(m, ["yes", "yeah", "yep", "ok", "okay", "sure"]):
		return _r(["Cool.", "Yay!", "Okay!"].pick_random())
	if _has(m, ["no", "nope", "nah"]):
		return _r(["Aw.", "Fair enough.", "Hmph."].pick_random())

	if message.strip_edges().ends_with("?"):
		return _r(QUESTION_REPLIES.pick_random())
	var words := m.strip_edges().split(" ")
	if words.size() <= 3 and randf() < 0.4:
		return _r("\"%s\"? Hmm..." % message.strip_edges())
	return _r(FALLBACKS.pick_random())


## Something Bob says on his own every so often.
static func ambient() -> String:
	match PetState.biggest_need():
		"hunger":
			return ["My tummy is rumbling...", "Is it snack time? It feels like snack time.", "*grumble grumble*"].pick_random()
		"energy":
			return ["*yawn*", "I could really use a nap.", "My stick legs are so tired..."].pick_random()
		"fun":
			return ["I'm sooo bored.", "Wanna play something?", "Hello? Anybody want to play?"].pick_random()
		"hygiene":
			return ["Is that smell... me?", "I think I need a shower.", "Even the flies are leaving."].pick_random()
	var hour: int = Time.get_time_dict_from_system()["hour"]
	if (hour >= 23 or hour < 5) and randf() < 0.3:
		return "It's really late... shouldn't you be asleep too?"
	return RANDOM_THOUGHTS.pick_random()


static func how_am_i() -> String:
	match PetState.biggest_need():
		"hunger":
			return "Honestly? Starving. Got any snacks?"
		"energy":
			return "So... sleepy... *yawn*"
		"fun":
			return "Kinda bored, to be honest."
		"hygiene":
			return "I feel a bit... crusty. Shower time?"
	var h := PetState.happiness()
	if h > 80.0:
		return "I'm doing GREAT! Best day ever!"
	if h > 55.0:
		return "Pretty good! Thanks for asking."
	return "I'm okay. Could be better."


static func _hunger_status() -> String:
	if PetState.hunger < 30.0:
		return "YES. So hungry. Please feed me!"
	if PetState.hunger < 70.0:
		return "I could eat. I could always eat."
	return "I'm full, thanks! Pizza is still my favorite though."


static func _energy_status() -> String:
	if PetState.energy < 30.0:
		return "I'm exhausted. Put me to bed?"
	if PetState.energy < 70.0:
		return "A little tired, but I'm okay."
	return "Sleep? I'm wide awake!"


static func _hygiene_status() -> String:
	if PetState.hygiene < 35.0:
		return "Okay... I might smell a little. Shower please?"
	return "I'm clean! Smell me. Actually, don't."


static func _fun_status() -> String:
	if PetState.fun < 35.0:
		return "YES please, let's play! I'm so bored."
	return "Playing is my favorite!"


static func _r(text: String, action := "", fun := 0.0) -> Dictionary:
	return {"text": text, "action": action, "fun": fun}


static func _normalize(text: String) -> String:
	var t := text.to_lower()
	t = RegEx.create_from_string("[^a-z0-9 ]").sub(t, "", true)
	t = RegEx.create_from_string("\\s+").sub(t, " ", true)
	return " " + t.strip_edges() + " "


static func _has(m: String, words: Array) -> bool:
	for word in words:
		if m.contains(" " + word + " "):
			return true
	return false
