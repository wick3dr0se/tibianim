import
  std/[asyncdispatch, httpclient],
  ../scraper

var client = newAsyncHttpClient()

# parse online players data
let players = waitFor client.onlinePlayers()

# list all players
#[
for player in players.all:
  echo(player)
]#

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

let house = waitFor client.searchHouse("Thais")

for h in house.all:
  echo(h)