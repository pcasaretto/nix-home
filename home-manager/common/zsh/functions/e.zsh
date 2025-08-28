e () {
    if [ $# -eq 0 ]
    then
        eval "${EDITOR} ."
    fi
    eval "${EDITOR} \"\$@\""
}
