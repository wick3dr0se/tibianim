import
  std/[asyncdispatch, httpclient],
  ../scraper


var client = newAsyncHttpClient()

#[ HIGHSCORES
let highscores = waitFor client.searchHighscores("all", "level")

for highscore in highscores.all:
  echo(highscore)
]#

# ---

#[ ONLINE
# parse online players data
let online = waitFor client.onlinePlayers()

# list online players
echo("Players Online ", online.count)
echo()

# show averge level
echo("Average Level ", online.avgLvl)
echo()

# list all vocations online
for voc in online.vocs:
  echo voc

# list the top player per vocations
for voc in online.topVocs:
  echo voc
echo()

# list all players online
for player in online.all:
  echo(player)
]#

# ---

# CHARACTER
# query player "papers" account
let character = waitFor client.searchCharacter("papers")

# list character information
for info in character.info:
  echo(info)
echo()

# list latest deaths
#if character.deaths.len() > 0:
for death in character.deaths:
  echo(death)
echo()

# list alt characters
echo character.alts

# ---

#[ HOUSES
let houses = waitFor client.searchHouses("Thais")

echo(houses.count, " houses found!")

for house in houses.all:
  echo(house)
echo()
]#