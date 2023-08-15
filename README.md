## Brainfuck in 93 Bytes of Code
```
$> gcc -s -static -nostartfiles -nodefaultlibs -nostdlib -Wl,--build-id=none bf.S -o bf
$> ./bf < hello-world.b
```

#### Why?
- For fun :)
- [According to Wikipedia](https://en.wikipedia.org/wiki/Brainfuck), Brainfuck was designed to be implementable with the smallest compiler possible. 240 bytes seemed like overkill.

#### TODO
- Make a complete elf file optimized for size (we don't need the page
  offset of non-exec for security, and there are a lot of tricks to
  optimize size in prog headers).
