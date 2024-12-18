global int y;

function sety(int val) {
    call printStr("Enter y value greater than 0:");
    call readInt();
    y = returnvalue;
}

function loop(string s) {
    while (y > 0) do {
        call printInt(y);
        y = y - 1;
    }
}

program {
    call sety(123);
    call printStr("\nThe value of y is: ");
    call printInt(y);
    call printStr("\n");
    if (y > 0) then {
        call loop("loops");
    } else {
        call printStr("Invalid input");
    }
}