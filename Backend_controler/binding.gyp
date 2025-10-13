{
  "targets": [
    {
      "target_name": "gamepad",
      "sources": [ "gamepad.cpp" ],
      "include_dirs": [
        "/mnt/A658E6FB58E6C8DF/Code/Projects/Cheaptroller/Backend_controler/node_modules/node-addon-api"
      ],
      "cflags!": [ "-fno-exceptions" ],
      "cflags_cc!": [ "-fno-exceptions" ],
      "defines": [ "NAPI_CPP_EXCEPTIONS" ]
    }
  ]
}
