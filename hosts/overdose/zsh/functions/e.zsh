e () {
    if [ $# -eq 0 ]
    then
        ''${=EDITOR} .
    fi
    ''${=EDITOR} $@
}
