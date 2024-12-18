
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "astree.h"
#include "symtable.h"

int yyerror(const char *s);
int yylex(void);
int debug = 0; 

int addString(char *s); 
extern int yylineno;

int lastStringIndex = 0;
char *savedStrings[128];

int addString(char *s) {
    int i = lastStringIndex++;
    savedStrings[i] = strdup(s);
    return i;
}
Symbol** table;
int argNum = 0;
int paramNum = 0;
ASTNode* astRoot;

void outputDataSec(FILE *out){
        fprintf(out, "\t.data\n");
        // Loop through savedStrings to generate string data
        for (int i = 0; i < lastStringIndex; i++) {
            fprintf(out, ".SC%d:\t.string\t%s\n", i, savedStrings[i]);
        }
        
        Symbol* cur;
        SymbolTableIter iter;
        iter.index = -1;
        while((cur = iterSymbolTable(table, 0, &iter)) != NULL) {
            if (cur->scopeLevel == 0 && cur->kind != V_GLARRAY) {
                fprintf(out, "%s:\t.word\t0\n", cur->name);
            }
            else if(cur->scopeLevel == 0 && cur->kind == V_GLARRAY) {
               fprintf(out, "%s:\t.space\t400\n", cur->name);
            }
        }
        freeAllSymbols(table);
        fprintf(out, "\n");
}
%}

/* token value data types */
%union { 
   int ival;  // for most scanner tokens
   char* str; // tokens that need a string, like ID and STRING
   struct astnode_s * astnode; // for all grammar nonterminals
}

%start wholeprogram
%type <astnode> wholeprogram globals assignment vardecl parameters paramdecl program statements statement funcall function functions arguments argument expression ifthenelse whileloop boolexpr localvars localdecl dowhileloop

%token KWPROGRAM KWCALL KWFUNCTION KWGLOBAL KWINT KWSTRING KWRETURNVALUE KWIF KWTHEN KWELSE KWWHILE KWDO KWRETURN 
%token <str> ID STRING
%token <ival>LBRACE RBRACE LPAREN RPAREN SEMICOLON NUMBER COMMA EQUALS RELOP ADDOP LBRACKET RBRACKET UNARY RELOP_LE RELOP_GE

%right ADDOP

%%

wholeprogram: globals functions program
         {
            if (debug) printf("yacc: wholeprogram\n");
            $$ = (ASTNode*) newASTNode(AST_PROGRAM); // Create a new AST node
            $$->child[0] = $1; // Set the globals
            $$->child[1] = $2; // Set the functions
            $$->child[2] = $3; // Set the program
            $$->strNeedsFreed = 0; // Set the flag to free the string
            astRoot = $$; // Set the root of the AST
         }
         ;

program: KWPROGRAM LBRACE statements RBRACE
         {
            if (debug) printf("yacc: program\n");
            $$ = $3; // Set the statements
         }
         ;

functions: function functions
         {
            if (debug) printf("yacc: functions\n");
            $1->next = $2;
            $$ = $1;
         }

         | /* empty */
         {
            if (debug) printf("yacc: functions empty\n");
            $$ = 0; 
         }
         ;

function: KWFUNCTION ID LPAREN parameters RPAREN LBRACE localvars statements RBRACE
         {
            if (debug) fprintf(stderr,"function def\n");
            $$ = (ASTNode*) newASTNode(AST_FUNCTION);
            $$->strval = $2;
            $$->strNeedsFreed = 1;
            $$->child[0] = $4;
            $$->child[1] = $8;
            $$->child[2] = $7; // note: local vars are here; you could rearrange child nodes if you want
            delScopeLevel(table, 1); // important: remove param/local decls from symtable
            paramNum = 0;  // important: reset param/local counter
            paramNum = 0;
         }
         ;

statements: statement statements
         {
            if (debug) printf("yacc: statements\n");
            $1->next = $2;
            $$ = $1;
         }

         | /* empty */
         {
            if (debug) printf("yacc: statements empty\n");
            $$ = 0; // Return a null pointer
         }
         ;

statement: funcall
         {
            if (debug) printf("yacc: statement (funcall)\n");
            $$ = $1; // Set the function call
         }
         
         | assignment
         {
            if (debug) printf("yacc: statement (assignment)\n");
            $$ = $1; // Set the assignment
         }

         | ifthenelse
         {
            if (debug) printf("yacc: statement (ifthenelse)\n");
            $$ = $1; // Set the assignment
         }

         | whileloop
         {
            if (debug) printf("yacc: statement (whileloop)\n");
            $$ = $1; // Set the assignment
         }

         | KWRETURN expression SEMICOLON
         {
            if (debug) printf("yacc: statement (return)\n");
            $$ = (ASTNode*) newASTNode(AST_RETURN); // Create a new AST node
            $$->child[0] = $2; // Set the expression
         }

         | dowhileloop
         {
            if (debug) printf("yacc: statement (dowhileloop)\n");
            $$ = $1; // Set the assignment
         }
         ;

funcall: KWCALL ID LPAREN arguments RPAREN SEMICOLON
         {
            if (debug) printf("yacc: funcall\n");
            $$ = (ASTNode*) newASTNode(AST_FUNCALL); // Create a new AST node
            $$->strval = $2; // Set the function name
            $$->strNeedsFreed = 1; // Set the flag to free the string
            $$->child[0] = $4; // Set the arguments
         }
         ;

assignment: ID EQUALS expression SEMICOLON
         {
            if (debug) printf("yacc: assignment\n");
            Symbol* sym = findSymbol(table, $1);
            if (sym == NULL) {
               fprintf(stderr, "Error: line %d: Variable %s not declared\n", yylineno, $1);
               exit(1);
            }
            else if (sym->kind == V_GLOBAL){
               $$ = (ASTNode*) newASTNode(AST_ASSIGNMENT); // Create a new AST node
               $$->strval = $1; // Set the variable name
               $$->strNeedsFreed = 1; // Set the flag to free the string
               $$->child[0] = $3; // Set the expression
               $$->varKind = V_GLOBAL;
               $$->ival = sym->offset;
            }
            else if (sym->kind == V_LOCAL){
               $$ = (ASTNode*) newASTNode(AST_ASSIGNMENT); // Create a new AST node
               $$->varKind = V_LOCAL; // Set the variable kind
               $$->valType = T_INT; // Set the variable type
               $$->strval = $1; // Set the variable name
               $$->strNeedsFreed = 1; // Set the flag to free the string
               $$->child[0] = $3;
               $$->ival = sym->offset;
            }
            else if (sym->kind == V_GLARRAY){
               $$ = (ASTNode*) newASTNode(AST_ASSIGNMENT); // Create a new AST node
               $$->varKind = V_GLARRAY; // Set the variable kind
               $$->valType = T_INT; // Set the variable type
               $$->strval = $1; // Set the variable name
               $$->strNeedsFreed = 1; // Set the flag to free the string
               $$->child[0] = $3;
               $$->ival = sym->offset;
            }
            else if (sym->kind == V_PARAM){
               $$ = (ASTNode*) newASTNode(AST_ASSIGNMENT); // Create a new AST node
               $$->varKind = V_PARAM; // Set the variable kind
               $$->valType = T_INT; // Set the variable type
               $$->strval = $1; // Set the variable name
               $$->strNeedsFreed = 1; // Set the flag to free the string
               $$->child[0] = $3;
               $$->ival = sym->offset;
            }
         }
         
         | ID LBRACKET expression RBRACKET EQUALS expression SEMICOLON
         {
            if (debug) printf("yacc: assignment\n");
            $$ = (ASTNode*) newASTNode(AST_ASSIGNMENT); // Create a new AST node
            $$->varKind = V_GLARRAY;
            $$->strval = $1; // Set the variable name
            $$->strNeedsFreed = 1; // Set the flag to free the string
            $$->child[0] = $6; // Set the expression
            $$->child[1] = $3; // Set the expression
         }
         ;

arguments: /* empty */
         {
            if (debug) printf("yacc: arguments empty\n");
            $$ = 0; // Return a null pointer
         }

         | argument
         {
            if (debug) printf("yacc: arguments\n");
            $$ = (ASTNode*) newASTNode(AST_ARGUMENT); // Create a new AST node  
            $$->child[0] = $1; // Set the argument
            $$->strNeedsFreed = 0; // Set the flag to free the string
         }

         | argument COMMA arguments
         {
            if (debug) printf("yacc: arguments Comma Arguments\n");
            $$ = (ASTNode*) newASTNode(AST_ARGUMENT); // Create a new AST node
            $$->next = $3; // Set the next argument
            $$->child[0] = $1; // Set the argument
            $$->strNeedsFreed = 0; // Set the flag to free the string
         }
         ;

argument: expression
         {
            if (debug) printf("yacc: argument (expression) \n");
            $$ = $1; // Set the expression
         }
         ;

expression: 
        NUMBER
         {
            if (debug) printf("yacc: expression (number) \n");
            $$ = (ASTNode*) newASTNode(AST_CONSTANT); // Create a new AST node
            $$->valType = T_INT; // Set the variable type
            $$->ival = $1; // Set the integer value
            
         }

         | ID
         {
            if (debug) printf("yacc: expression (id) \n");
            Symbol* sym = findSymbol(table, $1);
            if (sym == NULL) {
               fprintf(stderr, "Error: line %d: Variable %s not declared\n", yylineno, $1);
               exit(1);
            }
            else if (sym->kind == V_GLOBAL){
               $$ = (ASTNode*) newASTNode(AST_VARREF); // Create a new AST node
               $$->varKind = V_GLOBAL; // Set the variable kind
               $$->valType = T_INT; // Set the variable type
               $$->strval = $1; // Set the variable name
               $$->strNeedsFreed = 1; // Set the flag to free the string
               $$->ival = sym->offset;
            }
            else if (sym->kind == V_LOCAL){
               $$ = (ASTNode*) newASTNode(AST_VARREF); // Create a new AST node
               $$->varKind = V_LOCAL; // Set the variable kind
               $$->valType = T_INT; // Set the variable type
               $$->strval = $1; // Set the variable name
               $$->strNeedsFreed = 1; // Set the flag to free the string
               $$->ival = sym->offset;
            }
            else if (sym->kind == V_GLARRAY){
               $$ = (ASTNode*) newASTNode(AST_VARREF); // Create a new AST node
               $$->varKind = V_GLARRAY; // Set the variable kind
               $$->valType = T_INT; // Set the variable type
               $$->strval = $1; // Set the variable name
               $$->strNeedsFreed = 1; // Set the flag to free the string
               $$->ival = sym->offset;
            }
            else if (sym->kind == V_PARAM){
               $$ = (ASTNode*) newASTNode(AST_VARREF); // Create a new AST node
               $$->varKind = V_PARAM; // Set the variable kind
               $$->valType = T_INT; // Set the variable type
               $$->strval = $1; // Set the variable name
               $$->strNeedsFreed = 1; // Set the flag to free the string
               $$->ival = sym->offset;
            }

         }

         | ID LBRACKET expression RBRACKET
         {
            if (debug) printf("yacc: expression (id) \n");
            //fix
            $$ = (ASTNode*) newASTNode(AST_VARREF); // Create a new AST node
            $$->varKind = V_GLARRAY; // Set the variable kind
            $$->valType = T_INT; // Set the variable type
            $$->strval = $1; // Set the variable name
            $$->strNeedsFreed = 1; // Set the flag to free the string
            $$->child[0] = $3;
         }

         | STRING
         {
            if (debug) printf("yacc: expression (string) \n");
            $$ = (ASTNode*) newASTNode(AST_CONSTANT); // Create a new AST node
            $$->valType = T_STRING; // Set the variable type
            $$->strval = $1; // Set the string value
            $$->strNeedsFreed = 1; // Set the flag to free the string
            $$->ival = addString($1); // Add the string to the string table

         }

         | KWRETURNVALUE
         {
            if (debug) printf("yacc: explanation (KWRETURNVALUE)\n");
            $$ = (ASTNode*) newASTNode(AST_CONSTANT); // Create a new AST node
            $$->valType = T_RETURNVAL; // Set the variable type
         }

         | expression ADDOP expression
         {
            if (debug) printf("yacc: expression (ADDOP) expression \n");
            $$ = (ASTNode*) newASTNode(AST_EXPRESSION); // Create a new AST node
            $$->ival = $2; // Set the operator
            $$->child[0] = $1; // Set the left expression
            $$->child[1] = $3; // Set the right expression
         }

         | UNARY expression 
         {
            if (debug) printf("yacc: expression (UNARY) expression \n");
            $$ = (ASTNode*) newASTNode(AST_UNARY); // Create a new AST node
            $$->ival = $1; // Set the operator
            $$->child[0] = $2; // Set the right expression
         }

         | LPAREN expression RPAREN
         {
            if (debug) printf("yacc: expression (expression) \n");
            $$ = $2; // Set the expression
         }
         ;
         
globals: /* empty */
         {
            if (debug) printf("yacc: globals empty\n");
            $$ = 0; // Return a null pointer
         }

         | KWGLOBAL vardecl SEMICOLON globals
         {
            if (debug) printf("yacc: globals\n");
            $2->next = $4;
            $$ = $2;
         }
         ;

vardecl: KWINT ID
         {
         if (debug) printf("yacc: vardecl (int) \n");
         // Add the variable to the symbol table
         if(!addSymbol(table, $2, 0, T_INT, 0, 0, V_GLOBAL)){
            $$ = (ASTNode*) newASTNode(AST_VARDECL); // Create a new AST node
            $$->valType = T_INT; // Set the variable type
            $$->varKind = V_GLOBAL; // Set the variable kind
            $$->strNeedsFreed = 1; // Set the flag to free the string
            $$->strval = $2; // Set the variable name
         }
         
         else{
            fprintf(stderr, "Error: line %d: Variable %s already declared\n", yylineno, $2);
            exit(1);                    
         }
         }


         | KWSTRING ID

         {
         if (debug) printf("yacc: vardecl (string) \n");
         // Add the variable to the symbol table
         if(!addSymbol(table, $2, 0, T_INT, 0, 0, V_GLOBAL)){
            $$ = (ASTNode*) newASTNode(AST_VARDECL); // Create a new AST node
            $$->strval = $2; // Set the variable name
            $$->valType = T_STRING; // Set the variable type
            $$->varKind = V_GLOBAL; // Set the variable kind
            $$->strNeedsFreed = 1; // Set the flag to free the string
         }
         else{
            fprintf(stderr, "Error: line %d: Variable %s already declared\n", yylineno, $2);
            exit(1);                    
         }
         
         }

         | KWINT ID LBRACKET NUMBER RBRACKET 
         {
            if (debug) printf("yacc: vardecl (string) \n");
            if(addSymbol(table, $2, 0, T_INT, $4, 0, V_GLARRAY)){
               fprintf(stderr, "Error: line %d: Variable %s already declared\n", yylineno, $2);
               exit(1); 
            }
            $$ = (ASTNode*) newASTNode(AST_VARDECL);
            $$->strval = $2;
            $$->strNeedsFreed = 1;
            $$->valType = T_INT;
            $$->ival = $4;
            $$->varKind = V_GLARRAY;
         }
         ;

parameters: /* empty */
         {
            if (debug) printf("yacc: parameters empty\n");
            $$ = 0; // Return a null pointer
         }

         | paramdecl
         {
            if (debug) printf("yacc: parameters\n");
            $$ = $1; // Set the parameter
         }

         | paramdecl COMMA parameters
         {
            if (debug) printf("yacc: parameters Comma Parameters\n");
            $1->next = $3; // Set the next parameter
            $$ = $1; // Set the parameter
         }
         ;

paramdecl: KWINT ID
         {
            if(addSymbol(table, $2, 1, T_INT, 0, paramNum, V_PARAM)) {
               fprintf(stderr, "Error: line %d: Variable %s already declared\n", yylineno, $2);
               exit(1); 
            }
            $$ = (ASTNode*) newASTNode(AST_VARDECL);
            $$->strval = $2;
            $$->strNeedsFreed = 1;
            $$->valType = T_INT;
            $$->ival = paramNum++;
            $$->varKind = V_PARAM;
            // note: local var actions are exactly the same except they use V_LOCAL
         }

         | KWSTRING ID
         {
            if (debug) printf("yacc: paramdecl (string) \n");
            if(addSymbol(table, $2, 1, T_INT, 0, paramNum, V_PARAM)) {
               fprintf(stderr, "Error: line %d: Variable %s already declared\n", yylineno, $2);
               exit(1); 
            }
            $$ = (ASTNode*) newASTNode(AST_VARDECL); // Create a new AST node
            $$->varKind = V_PARAM; // Set the variable kind
            $$->ival = paramNum++;
            $$->valType = T_STRING; // Set the variable type
            $$->strval = $2; // Set the parameter name
            $$->strNeedsFreed = 1; // Set the flag to free the string
         }
         ;

localvars: /* empty */
         {
            if (debug) printf("yacc: localvars empty\n");
            $$ = 0; // Return a null pointer
         }
         
         | localdecl SEMICOLON localvars
         {
            if (debug) printf("yacc: localvars\n");
            $1->next = $3;
            $$ = $1;
         }
         ;
localdecl: KWINT ID 
         {
            if (debug) printf("yacc: localdecl\n");
            if(addSymbol(table, $2, 1, T_INT, 0, paramNum, V_LOCAL)) {
               fprintf(stderr, "Error: line %d: Variable %s already declared\n", yylineno, $2);
               exit(1); 
            }
            $$ = (ASTNode*) newASTNode(AST_VARDECL);
            $$->strval = $2;
            $$->strNeedsFreed = 1;
            $$->valType = T_INT;
            $$->ival = paramNum++;
            $$->varKind = V_LOCAL;
            // note: local var actions are exactly the same except they use V_LOCAL
         } 

         | KWSTRING ID
         {
            if (debug) printf("yacc: localdecl\n");
            if(addSymbol(table, $2, 1, T_INT, 0, paramNum, V_LOCAL)){
               fprintf(stderr, "Error: line %d: Variable %s already declared\n", yylineno, $2);
               exit(1); 
            }
            $$ = (ASTNode*) newASTNode(AST_VARDECL);
            $$->strval = $2;
            $$->strNeedsFreed = 1;
            $$->valType = T_STRING;
            $$->ival = paramNum++;
            $$->varKind = V_LOCAL;
            // note: local var actions are exactly the same except they use V_LOCAL
         }
         ;

ifthenelse: KWIF LPAREN boolexpr RPAREN KWTHEN LBRACE statements RBRACE KWELSE LBRACE statements RBRACE
         {
            if (debug) printf("yacc: ifthenelse\n");
            $$ = (ASTNode*) newASTNode(AST_IFTHEN); // Create a new AST node
            $$->child[0] = $3;
            $$->child[1] = $7;
            $$->child[2] = $11;
         }

whileloop: KWWHILE LPAREN boolexpr RPAREN KWDO LBRACE statements RBRACE
         {
            if (debug) printf("yacc: whileloop \n");
            $$ = (ASTNode*) newASTNode(AST_WHILE); // Create a new AST node
            $$->child[0] = $3;
            $$->child[1] = $7;
         }

boolexpr: expression RELOP expression 
         {
            if (debug) printf("yacc: boolexpr \n");
            $$ = (ASTNode*) newASTNode(AST_RELEXPR); // Create a new AST node
            $$->ival = $2;
            $$->child[0] = $1;
            $$->child[1] = $3;
         }

         | expression RELOP_LE expression
         {
            if (debug) printf("yacc: boolexpr \n");
            $$ = (ASTNode*) newASTNode(AST_RELEXPR); // Create a new AST node
            $$->ival = 1; // Set the operator
            $$->child[0] = $1; // Set the left expression
            $$->child[1] = $3; // Set the right expression
         }

         | expression RELOP_GE expression
         {
            if (debug) printf("yacc: boolexpr \n");
            $$ = (ASTNode*) newASTNode(AST_RELEXPR); // Create a new AST node
            $$->ival = 2; // Set the operator
            $$->child[0] = $1; // Set the left expression
            $$->child[1] = $3; // Set the right expression
         }
         ;

dowhileloop: KWDO LBRACE statements RBRACE KWWHILE LPAREN boolexpr RPAREN SEMICOLON
         {
            if (debug) printf("yacc: dowhileloop \n");
            $$ = (ASTNode*) newASTNode(AST_DOWHILE); // Create a new AST node
            $$->child[0] = $3; // Set the statements
            $$->child[1] = $7; // Set the boolean expression
         }
%%
extern FILE *yyin;
int main(int argc, char **argv)
{
   int stat, last;
   FILE* outf;
   char outfilename[256]; // unsafe!
   int doAssembly = 1;
   char* infilename=NULL;
   if (argc < 2) {
      fprintf(stderr,"Error: no arguments!\n");
      return 1;
   }
   for (int i=1; i < argc; i++) {
      if (!strcmp(argv[i],"-t"))
         debug = 1;
      else if (!strcmp(argv[i],"-d"))
         doAssembly = 0;
      else if (!infilename)
         infilename = argv[i];
      else {
         fprintf(stderr,"Unexpected argument: (%s)\n", argv[i]);
         return 1;
      }
   }
   if (!infilename) {
      fprintf(stderr,"Error: no filename given!\n");
      return 1;
   }
   last = strlen(infilename) - 1;
   if (infilename[last] != 'j' || infilename[last-1] != '.') {
      fprintf(stderr,"Error: filename does not end in '.j'!\n");
      return 1;
   }
   strcpy(outfilename, infilename);
   outfilename[last] = 's';
   yyin = fopen(infilename,"r");
   if (!yyin) {
      fprintf(stderr,"Error: unable to open (%s)\n", argv[1]);
      return 2;
   }
   table = newSymbolTable();
   stat = yyparse();
   fclose(yyin);
   if (stat) {
      fprintf(stderr,"Error %d in parsing!\n", stat);
      return 1;
   }
   if (doAssembly) {
      outf = fopen(outfilename,"w");
      outputDataSec(outf);
      genCodeFromASTree(astRoot, 0, outf);
      fclose(outf);
   } else {
      printASTree(astRoot, 0, stdout);
   }
   freeAllSymbols(table);
   free(table);
   freeASTree(astRoot);
   yylex_destroy();
   return stat;
}

int yyerror(const char *s)
{
   fprintf(stderr, "Error: line %d: %s\n", yylineno, s);
   return 0;
}

int yywrap()
{
   return 1;
}