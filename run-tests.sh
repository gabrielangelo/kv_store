#!/bin/bash

test() {
    docker-compose -f docker-compose.test.yml run --rm test
}

test_file() {
    docker-compose -f docker-compose.test.yml run --rm test mix test "$1"
}

test_coverage() {
    docker-compose -f docker-compose.test.yml run --rm test mix test --cover
}

test_clean() {
    docker-compose -f docker-compose.test.yml down -v
    rm -rf _build
    rm -rf deps
}

case "$1" in
    "clean")
        test_clean
        ;;
    "coverage")
        test_coverage
        ;;
    *)
        if [ -z "$1" ]; then
            test
        else
            test_file "$1"
        fi
        ;;
esac