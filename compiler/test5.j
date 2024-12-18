global int result;

function testRelationalOperators()
{
    result = 0;

    do {
        call printStr("Result = ");
        call printInt(result);
        call printStr("\nresult <= 5: ");
        if (result <= 5) then {
            call printStr("true\n");
        }
        else {
            call printStr("false\n");
        }
        result = result + 1;
    } while (result < 10);
}

program {
    call printStr("Testing relational operators:\n");
    call testRelationalOperators();
    call printStr("Relational operators test complete.\n");
}