global int y;

function func1(int n) {
    int x;
    x = n + y;
    return x;
}

program {
    y = 10;
    call printStr("Enter value for y: ");
    call printInt(y);
    call func1(5);
    y = returnvalue;
    call printStr("\nThe value of y after func1 is: ");
    call printInt(y);
}