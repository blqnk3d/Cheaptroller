{
  "targets": [
    {
      "target_name": "gamepad",
      "sources": [ "gamepad.cpp" ],
      "include_dirs": [
        "<!@(node -p \"require('node-addon-api').include\")"
      ],
      "cflags!": [ "-fno-exceptions" ],
      "cflags_cc!": [ "-fno-exceptions" ],
      "defines": [ "NAPI_DISABLE_CPP_EXCEPTIONS" ],
      "dependencies": [ "<!(node -p \"require('node-addon-api').gyp\")" ]
    }
  ]
}
