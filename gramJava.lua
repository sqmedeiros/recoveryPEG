entry {
	g = [[
  blockstmt <- '{' <stmt>* '}'
  stmt <- <ifstmt> / <whilestmt> / <printstmt> / <decstmt> / <assignstmt> / <blockstmt>
  ifstmt <- 'if' '(' <exp> ')' <stmt> ('else' <stmt> / '') 
  whilestmt <-  'while' '(' <exp> ')' <stmt> 
  decstmt <- 'int' <NAME> ('=' <exp> / '') ';'
  assignstmt <- <NAME> '=' <exp> ';'
  printstmt <-  'System.out.println' '(' <exp> ')' ';'
  exp <-  <relexp> ('==' <relexp>)*
  relexp <- <addexp> ('<' <addexp>)*
  addexp <- <mulexp> (<ADDOP> <mulexp>)*
  ADDOP <- '+' / '-'
  mulexp <- <atomexp> (<MULOP> <atomexp>)*
  MULOP <- '*' / '/' 
  atomexp <- '(' <exp> ')' / <NUMBER> / <NAME>
  NUMBER <- ('-' / '') '1''1'*
  KEYWORDS <- 'if' / 'while' / 'public' / 'class' / 'static' / 'else' / 'void' / 'int'
  RESERVED <- <KEYWORDS> !'a'
  NAME <- !<RESERVED> 'a''a'* ]],
	s = "blockstmt",
	input = {}
}
