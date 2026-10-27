# LudumDare42
My game for Ludum Dare 42 (https://ldjam.com/events/ludum-dare/42)

## Building for the web (HTML5)

You need the Linux snap of Solar2D (its console builder cannot build HTML5, the build goes through the simulator GUI):

```sh
curl -LO https://github.com/coronalabs/corona/releases/download/3711/Solar2D-Linux-2024.3711_amd64.snap
sudo snap install --dangerous --devmode ./Solar2D-Linux-2024.3711_amd64.snap
```

Then run `./build-html5.sh`: it copies the project to `~/ld42-html5/src` (the snap can only see `$HOME`),
opens the simulator and prints what to enter in the `File → Build → HTML5` dialog (`Ctrl+Alt+B`).
After the simulator is closed the result is in `builds/oh-no-monsters.html5/`.

Running locally (`file://` does not work, an http server is needed):

```sh
./build-html5.sh serve     # or: python3 -m http.server -d builds/oh-no-monsters.html5 8000
```
