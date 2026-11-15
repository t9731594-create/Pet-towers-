# Roblox API check (15 Nov 2026)

Checked against the Creator docs source (github.com/Roblox/creator-docs); create.roblox.com itself could
not be opened from the build session. Nothing has run in Studio.

## OK as written
IsFriendsWithAsync (IsFriendsWith is deprecated), SocialService invite calls (client), CaptureService
CaptureScreenshot / PromptSaveCapturesToGallery behind PolicyService IsContentSharingAllowed,
workspace:GetServerTimeNow, UpdateAsync (nil cancels), ProximityPrompt members, PivotTo, RemoteEvent
queueing before the client connects, FredokaOne, Frame + UICorner + UIStroke rings, ScreenGui safe insets,
AnalyticsService and MarketplaceService signatures.

## Fixed after the check
- Friend check uses IsFriendsWithAsync only.
- Shutdown saves: retry waits cut to 12 s in all so they fit the 30 s BindToClose window.
- Economy analytics call now passes transaction type and SKU in the documented order.
- Streaming: the server asks for the destination area before moving a player (RequestStreamAroundAsync);
  the Secret lantern lookup no longer waits for parts that are not streamed in.

## Still open
- With streaming on, a Secret's lantern glow does not appear for a player who arrives on the floor after the chime started (the banner and the pet still do).
- Not confirmed in the docs: server-side IsFriendsWithAsync, any age gate for CaptureService, PivotTo timing right after CharacterAdded.
- Analytics events only log in a published game, so the funnel cannot be seen until soft launch.
