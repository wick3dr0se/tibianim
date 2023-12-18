import
  std/[asyncdispatch, httpclient, sequtils],
  ../scraper


var client = newAsyncHttpClient()

# parse online players data
let players = waitFor client.onlinePlayers()

echo players.topRook
echo players.topKnight

#[
# list all players
for player in players.all:
  echo(player)

# list online players
echo("Players Online ", players.count)
echo()

# list each vocation online count
for voc in players.voc:
  echo(voc)
echo()

# show averge level
echo("Average Level ", players.avgLvl)
echo()
]#

#[
# qiery player "papers"
let search = waitFor client.searchPlayer("papers")

# list character information
for s in search.info:
  echo(s)
echo()

# list latest deaths
if search.deaths.len() > 0:
  for d in search.deaths:
    echo(d)
  echo()

# list account alt characters
for c in search.alts:
  echo c.all
]#

#[
let houses = waitFor client.searchHouses("Thais")

for h in houses.all:
  echo(h)

let
  highscores = waitFor client.searchHighscores("all", "level")
  hs = (highscores.number, highscores.name, highscores.voc, highscores.skill, highscores.exp)

for i in 0..<hs[0].len:
  if i < 10:
    echo(hs[0][i], ". ", hs[1][i], " | ", hs[2][i], " | Lvl: ", hs[3][i], " Exp: ", hs[4][i])
]#
