global int result;

function testParentheses()
{
    result = (2 + 3);
    call printStr("Result of (2 + 3):");
    call printInt(result);
    call printStr("\n");

    result = (10 + (2 & 3)) + (1 | 4);
    call printStr("Result of (10 + (2 & 3)) + (1 | 4) is: ");
    call printInt(result);
    call printStr("\n");
}

program {
    call printStr("Testing parenthesized expressions:\n");
    call testParentheses();
    call printStr("Parentheses test complete.\n");
}