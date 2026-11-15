-- Robux items (bible B13). PROPOSALS ONLY: nothing here is on sale until the owner approves each price.
-- Nothing sold may be random or change any odds.
local Shop = {}
Shop.Approved = false
Shop.Passes = {
	{ key = "DoubleCoins", robux = 399 },
	{ key = "BiggerStack", robux = 249 },
	{ key = "CampPads8", robux = 199 },
	{ key = "AutoCollect", robux = 199 },
}
Shop.CoinPacks = { { seconds = 1800, robux = 49 }, { seconds = 7200, robux = 149 }, { seconds = 28800, robux = 399 } }
-- Roblox product / pass ids are filled in after the items are created in Creator Hub (needs approval).
Shop.PassIds = {} -- key -> game pass id
Shop.ProductCatalog = {} -- developer product id -> { kind = "coins", seconds = n } | { kind = "look", look = id }
Shop.Looks = {} -- { key, robux } cosmetics sold directly
return Shop
