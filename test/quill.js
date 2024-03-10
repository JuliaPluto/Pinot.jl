import {decode} from "https://deno.land/std@0.204.0/encoding/base64.ts";
import {TextLineStream} from "https://deno.land/std@0.204.0/streams/mod.ts";
import Delta from "npm:quill-delta"

const lines = Deno.stdin.readable.pipeThrough(new TextDecoderStream())
                  .pipeThrough(new TextLineStream());

let exit = false;
for await (let line of lines) {
  const msg = JSON.parse(line);
  switch (msg.header) {
  case "transform": {
    let text = new Delta().insert(msg["text"])
    let a = new Delta(msg["a"]);
    let b = new Delta(msg["b"]);
    let res = a.transform(b, msg["priority"])
    let newtext = text.compose(a).compose(res).ops[0].insert
    console.log(JSON.stringify({ops : res, newtext}))
  }; break;
  case "exit":
    exit = true;
    break;
  default:
    throw (`invalid header ${msg.header}`);
  }
  if (exit) {
    break;
  }
}