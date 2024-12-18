//
// Abstract Syntax Tree Implementation
// - see "astree.h" for type definitions
// - the tree is made up of nodes of type ASTNode
// - the root node must be of type AST_PROGRAM
// - child nodes are linked by the "child[]" array, and
//   each type of node has its own children types
// - a special "child" node (the AST is a tree) uses
//   the "next" pointer to point to a "sibling"-type
//   node that is the next in a list (such as statements)
//
// Copyright (C) 2024 Jonathan Cook
//
#include <stdlib.h>
#include <stdio.h>
#include "astree.h"

// Create a new AST node 
// - allocates space and initializes node type, zeros other stuff out
// - returns pointer to new node
ASTNode* newASTNode(ASTNodeType type)
{
   int i;
   ASTNode* node = (ASTNode*) malloc(sizeof(ASTNode));
   if (node == NULL)
      return NULL;
   node->type = type;
   node->valType = T_INT;
   node->varKind = V_GLOBAL;
   node->ival = 0;
   node->strval = 0;
   node->strNeedsFreed = 0;
   node->next = 0;
   for (i=0; i < ASTNUMCHILDREN; i++)
      node->child[i] = 0;
   return node;
}

// Generate an indentation string prefix
// - this is a helper function for use in printing the abstract
//   syntax tree with indentation used to indicate tree depth.
// - NOT thread safe! (uses a static char array to hold prefix)
#define INDENTAMT 3
static char* levelPrefix(int level)
{
   static char prefix[128]; // static so that it can be returned safely
   int i;
   for (i=0; i < level*INDENTAMT && i < 126; i++)
      prefix[i] = ' ';
   prefix[i] = '\0';
   return prefix;
}

// Free an entire ASTree, along with string data it has
// - a node must have strNeedsFreed to non-zero in order 
//   for its strval to be freed
void freeASTree(ASTNode* node)
{
   if (!node)
      return;
   freeASTree(node->child[0]);
   freeASTree(node->child[1]);
   freeASTree(node->child[2]);
   freeASTree(node->next);
   if (node->strNeedsFreed && node->strval) 
      free(node->strval);
   free(node);
}

// Print the abstract syntax tree starting at the given node
// - this is a recursive function, your initial call should 
//   pass 0 in for the level parameter
// - comments in code indicate types of nodes and where they
//   are expected; this helps you understand what the AST looks like
// - "out" is the file to output to, can be "stdout" or other file handle
void printASTree(ASTNode* node, int level, FILE *out)
{
   if (!node)
      return;
   fprintf(out,"%s",levelPrefix(level)); // note: no newline printed here!
   switch (node->type) {
    case AST_PROGRAM:
       fprintf(out,"Whole Program AST:\n");
       fprintf(out,"%s--globalvars--\n",levelPrefix(level+1));
       printASTree(node->child[0],level+1,out);  // child 0 is gobal var decls
       fprintf(out,"%s--functions--\n",levelPrefix(level+1));
       printASTree(node->child[1],level+1,out);  // child 1 is function defs
       fprintf(out,"%s--program--\n",levelPrefix(level+1));
       printASTree(node->child[2],level+1,out);  // child 2 is program
       break;

    case AST_VARDECL:
      fprintf(out, "Variable declaration (%s)", node->strval);
      if (node->valType == T_INT) {
         if (node->varKind == V_PARAM) {
            fprintf(out, " type int\n");
         } else if (node->varKind == V_GLARRAY) {
            fprintf(out, " type int array size %d\n", node->ival);
        } else {
            fprintf(out, " type int\n");
         }
    } else if (node->valType == T_STRING) {
        fprintf(out, " type string\n");
    } else {
        fprintf(out, " type unknown (%d)\n", node->valType);
    }
    break;

    case AST_FUNCTION:
       fprintf(out,"Function def (%s)\n",node->strval); // function name
       fprintf(out,"%s--params--\n",levelPrefix(level+1));
       printASTree(node->child[0],level+1,out); // child 0 is param list
       fprintf(out,"%s--locals--\n",levelPrefix(level+1));
       printASTree(node->child[2],level+1,out); // child 2 is local vars
       fprintf(out,"%s--body--\n",levelPrefix(level+1));
       printASTree(node->child[1],level+1,out); // child 1 is body (stmt list)
       break;
    case AST_SBLOCK:
       fprintf(out,"Statement block\n"); // we don't use this type
       printASTree(node->child[0],level+1,out);  // child 0 is statement list
       break;
    case AST_FUNCALL:
       fprintf(out,"Function call (%s)\n",node->strval); // func name
       printASTree(node->child[0],level+1,out);  // child 0 is argument list
       break;
    case AST_ARGUMENT:
       fprintf(out,"Funcall argument\n");
       printASTree(node->child[0],level+1,out);  // child 0 is argument expr
       break;
    case AST_ASSIGNMENT:
       fprintf(out,"Assignment to (%s) ", node->strval);
       if (node->varKind == V_GLARRAY) { //child[1]) {
          fprintf(out,"array var\n");
          fprintf(out,"%s--index--\n",levelPrefix(level+1));
          printASTree(node->child[1],level+1,out);
       } else  
          fprintf(out,"simple var\n");
       fprintf(out,"%s--right hand side--\n",levelPrefix(level+1));
       printASTree(node->child[0],level+1,out);  // child 1 is right hand side
       break;
    case AST_WHILE:
       fprintf(out,"While loop\n");
       printASTree(node->child[0],level+1,out);  // child 0 is condition expr
       fprintf(out,"%s--body--\n",levelPrefix(level+1));
       printASTree(node->child[1],level+1,out);  // child 1 is loop body
       break;
    case AST_IFTHEN:
       fprintf(out,"If then\n");
       printASTree(node->child[0],level+1,out);  // child 0 is condition expr
       fprintf(out,"%s--ifpart--\n",levelPrefix(level+1));
       printASTree(node->child[1],level+1,out);  // child 1 is if body
       fprintf(out,"%s--elsepart--\n",levelPrefix(level+1));
       printASTree(node->child[2],level+1,out);  // child 2 is else body
       break;
    case AST_EXPRESSION: // only for binary op expression
       fprintf(out,"Expression (op %d,%c)\n",node->ival,node->ival);
       printASTree(node->child[0],level+1,out);  // child 0 is left side
       printASTree(node->child[1],level+1,out);  // child 1 is right side
       break;
    case AST_RELEXPR: // only for relational op expression
       fprintf(out,"Relational Expression (op %d,%c)\n",node->ival,node->ival);
       printASTree(node->child[0],level+1,out);  // child 0 is left side
       printASTree(node->child[1],level+1,out);  // child 1 is right side
       break;
    case AST_VARREF:
       fprintf(out,"Variable ref (%s)",node->strval); // var name
       if (node->varKind == V_GLARRAY) { //child[0]) {
          fprintf(out," array ref\n");
          printASTree(node->child[0],level+1,out);
       } else 
          fprintf(out,"\n");
       break;
    case AST_CONSTANT: // for both int and string constants
       if (node->valType == T_INT)
          fprintf(out,"Int Constant = %d\n",node->ival);
       else if (node->valType == T_STRING)
          fprintf(out,"String Constant = (%s)\n",node->strval);
       else if (node->valType == T_RETURNVAL) // NEW
          fprintf(out,"Return Value\n");
       else 
          fprintf(out,"Unknown Constant\n");
       break;
      case AST_RETURN: // for both int and string constants
         fprintf(out,"Return\n");
         printASTree(node->child[0],level+1,out);
         break;
      case AST_DOWHILE:
         fprintf(out,"Do-While loop\n");
         fprintf(out,"%s--body--\n",levelPrefix(level+1));
         printASTree(node->child[0],level+1,out);  // child 0 is loop body
         fprintf(out,"%s--condition--\n",levelPrefix(level+1));
         printASTree(node->child[1],level+1,out);  // child 1 is condition expr
         break;
      case AST_UNARY:
         fprintf(out,"Unary op %d\n",node->ival);
         printASTree(node->child[0],level+1,out);  // child 0 is operand
         break;
   }
   // IMPORTANT: walks down sibling list (for nodes that form lists, like
   // declarations, functions, parameters, arguments, and statements)
   printASTree(node->next,level,out);
}

//
// Below here is code for generating our output assembly code from
// an AST. You will probably want to move some things from the
// grammar file (.y file) over here, since you will no longer be 
// generating code in the grammar file. You may have some global 
// stuff that needs accessed from both, in which case declare it in
// one and then use "extern" to reference it in the other.

extern void outputDataSec(); // in main.c

// Used for labels inside code, for loops and conditionals
static int getUniqueLabelID()
{
   static int lid = 100; // you can start at 0, it really doesn't matter
   return lid++;
}

// Generate assembly code from AST
// - this function should look _alot_ like the print function;
//   indeed, the best way to start would be to copy over the 
//   code from printASTree() and change all the recursive calls
//   to this function; then, instead of printing info, we are 
//   going to print assembly code. Easy!
// - param node is the current node being processed
// - param hval is a helper value parameter that can be used to keep
//   track of value for you -- I use it only in two places, to keep
//   track of arguments and then to use the correct argument register
//   and to keep a label ID for conditional jumps on AST_RELEXPR 
//   nodes; otherwise this helper value can just be 0
// - param out is the output file handle. Use "fprintf(out,..." 
//   instead of printf(...); call it with "stdout" for terminal output
//   (see printASTree() code for how it uses the output file handle)
//
void genCodeFromASTree(ASTNode* node, int hval, FILE *out)
{
    if (!node)
        return;

    switch (node->type) {
        case AST_PROGRAM:
            fprintf(out, "\t.text\n");
            fprintf(out, "program:\n");
            genCodeFromASTree(node->child[2], hval, out);  // program
            fprintf(out, "\tli a0, 0\n\tli a7, 93\n\tecall\n");  // exit syscall
            fprintf(out, "#\n# Functions\n#\n\n");
            genCodeFromASTree(node->child[1], hval, out);  // function defs
            fprintf(out, "func_exit:\n");
            fprintf(out, "\tmv\tsp, fp\n"); // restore sp to fp pos, just in case func body erred  
            fprintf(out, "\tlw\tfp, 4(sp)\n"); // restore frame pointer
            fprintf(out, "\tlw\tra, 0(sp)\n"); // restore return address
            fprintf(out, "\taddi\tsp, sp, 128\n"); // remove stack space
            fprintf(out, "\tret\n");
            fprintf(out, "#\n# Library functions\n#\n\n");
            fprintf(out, "# Print a null-terminated string: arg: a0 == string address\nprintStr:\n\tli\ta7, 4\n\tecall\n\tret\n\n");
            fprintf(out, "# Print a decimal integer: arg: a0 == value\nprintInt:\n\tli\ta7, 1\n\tecall\n\tret\n\n");
            fprintf(out, "# Read in a decimal integer: return: a0 == value\nreadInt:\n\tli\ta7, 5\n\tecall\n\tret");
            break;

        case AST_VARDECL:
            // Global variable declarations are handled in the data section
            // This will be handled by outputDataSec() function
            
            break;

        case AST_FUNCTION:
            fprintf(out, "\n%s:\n", node->strval);
            fprintf(out, "\taddi\tsp, sp, -128\n");
            fprintf(out, "\tsw\tfp, 4(sp)\n");
            fprintf(out, "\tsw\tra, 0(sp)\n");
            fprintf(out, "\tmv\tfp, sp\n");
            fprintf(out, "\tsw\ta0, 8(sp)\n");
            fprintf(out, "\tsw\ta1, 12(sp)\n");
            fprintf(out, "\tsw\ta2, 16(sp)\n");
            fprintf(out, "\tsw\ta3, 20(sp)\n");
            fprintf(out, "\tsw\ta4, 24(sp)\n");
            fprintf(out, "\tsw\ta5, 28(sp)\n");
            genCodeFromASTree(node->child[0], hval, out);  // params
            genCodeFromASTree(node->child[2], hval, out);  // local vars
            genCodeFromASTree(node->child[1], hval, out);  // body
            fprintf(out, "\tj\tfunc_exit\n");
            break;

        case AST_FUNCALL:
            hval = 0;
            genCodeFromASTree(node->child[0], hval, out);  // arguments
            fprintf(out, "\tjal %s\n", node->strval);
            break;

        case AST_ARGUMENT:
            genCodeFromASTree(node->child[0], hval, out);
            fprintf(out, "\tmv\ta%d, t0\n", hval);
            break;

        case AST_ASSIGNMENT:
            fprintf(out,"\t#--assignment--\n");
            genCodeFromASTree(node->child[0],0,out);  // child 1 is right hand side
            if (node->varKind == V_GLOBAL) {
               fprintf(out, "\tsw\tt0, %s, t1\n", node->strval);//... single sw instruction using direct addressing using variable name
            } else if (node->varKind == V_PARAM || node->varKind == V_LOCAL) {
               fprintf(out, "\tsw\tt0, %d(fp)\n", (node->ival*4 ) + 8);//...sw instruction using indirect addressing using node->ival offset in formula
            } else if (node->varKind == V_GLARRAY) { //child[0]) {
               fprintf(out,"\taddi\tsp, sp, -4\n\tsw\tt0, 0(sp)\n"); // save RHS value onto stack
               genCodeFromASTree(node->child[1],0,out);  // generate code for index expression
               fprintf(out, "\tslli\tt0, t0, 2\n\tla\tt1, %s\n\tadd	t1, t1, t0\n\tlw\tt0, 0(sp)\n", node->strval);//...code to calculate array element address a
               fprintf(out,"\taddi\tsp, sp, -4\n\tsw\tt0, 0(t1)\n");//...code to add index offset to array beginning address, pop RHS value off stack and store it into array element);
            } else 
               fprintf(out,"Unknown variable kind assignment\n");
            break;

        case AST_WHILE:
            {
               fprintf(out, "\t# While loop\n");   
                int label1 = getUniqueLabelID();
                int label2 = getUniqueLabelID();
                fprintf(out, "\tb\t.LL%d\n.LL%d:\n", label2, label1);
                fprintf(out, "\t# body\n");
                genCodeFromASTree(node->child[1], hval, out);
                fprintf(out, "\t# condition\n");
                fprintf(out, ".LL%d:\n", label2);
                genCodeFromASTree(node->child[0], label1, out);
                fprintf(out, "\t# end while\n");
            }
            break;

        case AST_IFTHEN:
            {
                fprintf(out, "\t# If-then-else\n");
                int label1 = getUniqueLabelID();
                int label2 = getUniqueLabelID();
                genCodeFromASTree(node->child[0], label1, out);  // condition
                fprintf(out, "\t# else\n");
                genCodeFromASTree(node->child[2], hval, out);  // if body
                fprintf(out, "\tb\t.LL%d\n.LL%d:\n", label2, label1);
                fprintf(out, "\t# then\n");
                genCodeFromASTree(node->child[1], hval, out);  // else body
                fprintf(out, ".LL%d:\n\t# endif\n", label2);
            }
            break;

        case AST_EXPRESSION:
            switch (node->ival) {
                case '+': 
                  genCodeFromASTree(node->child[0], hval, out);
                  fprintf(out, "\taddi\tsp, sp, -4\n\tsw\tt0, 0(sp)\n");
                  genCodeFromASTree(node->child[1], hval, out);
                  fprintf(out, "\tlw\tt1, 0(sp)\n\taddi\tsp, sp, 4\n\tadd\tt0, t1, t0\n"); 
                  break;
               case '-': 
                  genCodeFromASTree(node->child[0], hval, out);
                  fprintf(out, "\taddi\tsp, sp, -4\n\tsw\tt0, 0(sp)\n");
                  genCodeFromASTree(node->child[1], hval, out);
                  fprintf(out, "\tlw\tt1, 0(sp)\n\taddi\tsp, sp, 4\n\tsub\tt0, t1, t0\n"); 
                  break;
               case '&': 
                  genCodeFromASTree(node->child[0], hval, out);
                  fprintf(out, "\taddi\tsp, sp, -4\n\tsw\tt0, 0(sp)\n");
                  genCodeFromASTree(node->child[1], hval, out);
                  fprintf(out, "\tlw\tt1, 0(sp)\n\taddi\tsp, sp, 4\n\tand\tt0, t1, t0\n"); 
                  break;
               case '|': 
                  genCodeFromASTree(node->child[0], hval, out);
                  fprintf(out, "\taddi\tsp, sp, -4\n\tsw\tt0, 0(sp)\n");
                  genCodeFromASTree(node->child[1], hval, out);
                  fprintf(out, "\tlw\tt1, 0(sp)\n\taddi\tsp, sp, 4\n\tor\tt0, t1, t0\n"); 
                  break;
               case '^': 
                  genCodeFromASTree(node->child[0], hval, out);
                  fprintf(out, "\taddi\tsp, sp, -4\n\tsw\tt0, 0(sp)\n");
                  genCodeFromASTree(node->child[1], hval, out);
                  fprintf(out, "\tlw\tt1, 0(sp)\n\taddi\tsp, sp, 4\n\txor\tt0, t1, t0\n"); 
                  break;
            }
            break;

        case AST_RELEXPR: // only for relational op expression
            fprintf(out,"\t# Relational Expression (op %d,%c)\n",node->ival,node->ival);
            genCodeFromASTree(node->child[0],hval,out);  // child 0 is left side
            fprintf(out,"\taddi\tsp, sp, -4\n\tsw\tt0, 0(sp)\n");
            genCodeFromASTree(node->child[1],hval,out);  // child 1 is right side
            // decide which instruction to use based on operator
            const char* instr;

            switch (node->ival) {
               case 1: instr = "ble"; break;
               case 2: instr = "bge"; break;
               case '=': instr = "beq"; break;
               case '!': instr = "bne"; break;
               case '<': instr = "blt"; break;
               case '>': instr = "bgt"; break;
               default: instr = "unknown relop";
            }
            fprintf(out,"\tlw\tt1, 0(sp)\n\taddi\tsp, sp, 4\n\t%s\tt1, t0, .LL%d\n",instr,hval);
            break;

        case AST_VARREF:
            if (node->varKind == V_GLOBAL) {
               fprintf(out, "\tlw\tt0, %s\n", node->strval);
            } else if (node->varKind == V_PARAM || node->varKind == V_LOCAL) {
               fprintf(out, "\tlw\tt0, %d(fp)\n", (node->ival*4) + 8);//...single lw instruction using indirect (frame pointer) addressing w/ node->ival
            } else if (node->varKind == V_GLARRAY) { //child[0] is index
               genCodeFromASTree(node->child[0],hval,out); // generate index expression code
               fprintf(out, "\tslli\tt0, t0, 2\n");
               fprintf(out, "\tla\tt1, %s\n", node->strval); // Load address of the global array
               fprintf(out, "\tadd\tt1, t1, t0\n");
               fprintf(out, "\tlw\tt0, 0(t1)\n");
            } else 
               fprintf(out,"Unknown variable kind reference\n");
            break;

        case AST_CONSTANT:
            if (node->valType == T_INT) {
                fprintf(out, "\tli\tt0, %d\n", node->ival);
            } else if (node->valType == T_STRING) {
                fprintf(out, "\tla\tt0, .SC%d\n", node->ival); 
                hval++; 
            }
            else if (node->valType == T_RETURNVAL) {
                fprintf(out, "\tmv\tt0, a0\n");
            }
            break;

         case AST_RETURN:
               genCodeFromASTree(node->child[0], hval, out);
               fprintf(out, "\tmv\ta0, t0\n");
               fprintf(out, "\tj\tfunc_exit\n");
               break;
         
         case AST_UNARY:
               genCodeFromASTree(node->child[0], hval, out);
               switch(node->ival) {
                  case '-':
                     fprintf(out, "neg t0, t0\n");
                     break;
                  case '~':
                     fprintf(out, "not t0, t0\n");
                     break;
                  default:
                     fprintf(stderr, "Unknown AST node type in code generation!\n");
                     break;
               }
               break;
         case AST_DOWHILE:
            {
               fprintf(out, "\t# Do-while loop\n");
               int label1 = getUniqueLabelID();  // Label for the loop body

               // Emit label for the body of the loop
               fprintf(out, ".LL%d:\n", label1);
               fprintf(out, "\t# Body of do-while loop\n");
               genCodeFromASTree(node->child[0], hval, out);
               genCodeFromASTree(node->child[1], label1, out);


               // Emit branch instruction to loop back if condition is true
               fprintf(out, "\t# End of do-while loop\n");
            }
            break;

         default:
               fprintf(stderr, "Unknown AST node type in code generation!\n");
               break;
    }

    genCodeFromASTree(node->next, hval+1, out);
}


