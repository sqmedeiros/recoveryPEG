entry {
	g = [[ A <- ('a' 'b')*]],
	s = "A",
	input = {}
}

entry {
	g = [[ A <- 'a' ('b''d' / 'b''c')]],
	s = "A",
	input = {}
}

entry {
	g = [[ A <- 'a' 'x' / 'a' 'y' / 'b' 'z']],
	s = "A",
	input = {}
}

entry {
	g = [[ A <- ('a' 'x' / 'a' 'y') / 'b' 'z']],
	s = "A",
	input = {}
}

entry {
	g = [[ A <- 'a' 'x' / ('a' 'y' / 'b' 'z')]],
	s = "A",
	input = {}
}

entry {
	g = [[ A <- 'c' ('a''a' / 'b''b' / '') 'a']],
	s = "A",
	input = {}
}

entry {
	g = [[ A <- 'c' ('a''a' / 'b''b' / '') 'b']],
	s = "A",
	input = {}
}

entry {
	g = [[ A <- 'c' ('a''a' / 'b''b' / '') 'c']],
	s = "A",
	input = {}
}
