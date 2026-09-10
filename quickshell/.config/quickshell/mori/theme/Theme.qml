pragma Singleton
import Quickshell
import QtQuick

Singleton {
  property string fg: "#d3c6aa"
  property string red: "#e67e80"
  property string yellow: "#dbbc7f"
  property string green: "#a7c080"
  property string blue: "#7fbbb3"
  property string purple: "#d699b6"
  property string aqua: "#83c092"
  property string orange: "#e69875"

  property string status1: "#a7c080" //green
  property string status2: "#d3c6aa" //white
  property string status3: "#e67e80" //red 

  property string grey: "#7a8478"
  property string grey1: "#859289"
  property string grey2: "#9da9a0"

  property string bgdim: "#1e2326"
  property string bg: "#272e33"
  property string bg1: "#2e383c"
  property string bg2: "#374145"
  property string bg3: "#414b50"
  property string bg4: "#495156"
  property string bg5: "#4f5b58"
  
  property string bgred: "#493b40"
  property string bgyellow: "#45443c"
  property string bggreen: "#3c4841"
  property string bgblue: "#384b55"
  property string bgpurple: "#463f48"
  property string bgvisual: "#4c3743"

// fonts — check exact names with: fc-list | grep -i nerd
    property string fontFamily: "sans-serif"
    property string nerdFontFamily: "FiraCode Nerd Font Propo"
    property int fontSize: 13
}
