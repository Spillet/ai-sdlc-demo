namespace Claims.Api.Content.Templates;

public sealed class ClaimReadyForPickupTemplate : IMessageTemplate
{
    public string Key => "claim-ready-for-pickup";
    public string Subject => "Reklamace {claimNumber} je připravená k vyzvednutí";
    public string Body =>
        "Dobrý den, zboží z reklamace {claimNumber} k objednávce {orderNumber} si můžete vyzvednout na výdejním místě. Uložené je do {resolveBy}.";
}
