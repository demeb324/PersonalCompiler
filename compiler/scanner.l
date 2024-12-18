/******
* Lex scanner for simple example
* - see the header comments in parser.y for more 
*   explanation of what this scanner does
******/

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifndef LEXONLY
#include "y.tab.h"
extern int debug; // declared and set in parser.y
#else
#define YYSTYPE yystype
typedef union { int ival; char* str; } yystype;

yystype yylval;

#define SEMICOLON  1
#define LBRACE  2
#define RBRACE  3
#define ID  4
#define KWPROGRAM  5
#define KWCALL  6
#define LPAREN  7
#define RPAREN  8
#define STRING 9
#define KWFUNCTION 10
#define NUMBER 11  // Add this definition
#define COMMA 12   // Add this definition
#define PLUS 13
#define KWINT 14
#define KWSTRING 15
#define KWGLOBAL 16
#define ADDOP 17
#define KWWHILE 18
#define KWDO 19
#define KWIF 20
#define KWTHEN 21
#define KWELSE 22
#define KWRETURNVALUE 23
#define RELOP 24
#define EQUALS 25
#define LBRACKET 26
#define RBRACKET 27
#define KWRETURN 28
#define UNARY 29
#define RELOP_LE 30
#define RELOP_GE 31

int debug=1;
#endif
%}

/* This option is useful for printing out a syntax error
*  message and printing out the line # it occurred on
*/
%option yylineno

%%
[ \t\n\r]+ { /* skipping white space */ }
\;       {
            if (debug) fprintf(stderr, "lex: semicolon\n");
            yylval.ival = yytext[0];
            return(SEMICOLON);
         }
\(       {
            if (debug) fprintf(stderr, "lex: left parenthesis\n");
            yylval.ival = yytext[0];   
            return(LPAREN);
         }
\)       {
            if (debug) fprintf(stderr, "lex: right parenthesis\n");
            yylval.ival = yytext[0];
            return(RPAREN);
         }
\{       {
            if (debug) fprintf(stderr, "lex: left brace\n");
            yylval.ival = yytext[0];
            return(LBRACE);
         }    
\}       {
            if (debug) fprintf(stderr, "lex: right brace\n");
            yylval.ival = yytext[0];
            return(RBRACE);
         }
\,       {
            if (debug) fprintf(stderr, "lex: comma\n");
            yylval.ival = yytext[0];
            return(COMMA);
         }
\[       {
            if (debug) fprintf(stderr, "lex: left bracket\n");
            return(LBRACKET);
         }
\]       {
            if (debug) fprintf(stderr, "lex: right bracket\n");
            return(RBRACKET);
         }
[\-\~]   {
            if (debug) fprintf(stderr, "lex: UNARY\n");
            yylval.ival = yytext[0];
            return(UNARY);
         }
[\+\-\&\|\^]   {
            if (debug) fprintf(stderr, "lex: ADDOP\n");
            yylval.ival = yytext[0];
            return(ADDOP);
         }
\=       {
            if (debug) fprintf(stderr, "lex: equal\n");
            yylval.ival = yytext[0];
            return(EQUALS);
         }
"<"     { if (debug) fprintf(stderr, "lex: RELOP\n"); yylval.ival = yytext[0]; return(RELOP); }
">"     { if (debug) fprintf(stderr, "lex: RELOP\n"); yylval.ival = yytext[0]; return(RELOP); }
"=="    { if (debug) fprintf(stderr, "lex: RELOP\n"); yylval.ival = yytext[0]; return(RELOP); }
"!="    { if (debug) fprintf(stderr, "lex: RELOP\n"); yylval.ival = yytext[0]; return(RELOP); }
"<="    { if (debug) fprintf(stderr, "lex: RELOP\n"); yylval.ival = yytext[0]; return(RELOP_LE); }
">="    { if (debug) fprintf(stderr, "lex: RELOP\n"); yylval.ival = yytext[0]; return(RELOP_GE); }
"program" {
            if (debug) fprintf(stderr, "lex: program keyword\n");
            yylval.ival = yytext[0];
            return(KWPROGRAM);
         }
"call" {
            if (debug) fprintf(stderr, "lex: call keyword\n");
            yylval.ival = yytext[0];
            return(KWCALL);
         }
"function" {
            if (debug) fprintf(stderr, "lex: function keyword\n");
            yylval.ival = yytext[0];
            return(KWFUNCTION);
         }
"int" {
            if (debug) fprintf(stderr, "lex: int keyword\n");
            yylval.ival = yytext[0];
            return(KWINT);
         }
"string" {
            if (debug) fprintf(stderr, "lex: string keyword\n");
            yylval.ival = yytext[0];
            return(KWSTRING);
         }
"global" {
            if (debug) fprintf(stderr, "lex: global keyword\n");
            yylval.ival = yytext[0];
            return(KWGLOBAL);
         }
"while" {
            if (debug) fprintf(stderr, "lex: while keyword\n");
            yylval.ival = yytext[0];
            return(KWWHILE);
         }
"do" {
            if (debug) fprintf(stderr, "lex: do keyword\n");
            yylval.ival = yytext[0];
            return(KWDO);
         }
"if" {
            if (debug) fprintf(stderr, "lex: if keyword\n");
            yylval.ival = yytext[0];
            return(KWIF);
         }
"then" {
            if (debug) fprintf(stderr, "lex: then keyword\n");
            yylval.ival = yytext[0];
            return(KWTHEN);
         }
"else" {
            if (debug) fprintf(stderr, "lex: else keyword\n");
            yylval.ival = yytext[0];
            return(KWELSE);
         }
"returnvalue" {
            if (debug) fprintf(stderr, "lex: returnvalue keyword\n");
            yylval.ival = yytext[0];
            return(KWRETURNVALUE);
         }
"return" {
            if (debug) fprintf(stderr, "lex: return keyword\n");
            yylval.ival = yytext[0];
            return(KWRETURN);
         }
[0-9]+   {
            if (debug) fprintf(stderr, "lex: number\n");
            yylval.ival = strtol(yytext, NULL, 10);
            return(NUMBER);
         }
[a-zA-Z_][a-zA-Z0-9_]* {
            if (debug) fprintf(stderr, "lex: identifier (%s)\n", yytext);
            yylval.str = strdup(yytext);
            return(ID);
         }
\"[^\"]*\"  {
            if (debug) fprintf(stderr, "lex: string (%s)\n", yytext);
            yylval.str = strdup(yytext);
            return(STRING);
         }

%%

#ifdef LEXONLY
int main(int argc, char **argv) 
{
   do {
      yylex();
   } while (1);
   return 0;
}

int yywrap()
{
   return 1; // Change to return 1 for EOF handling
}
#endif // LEXONLY