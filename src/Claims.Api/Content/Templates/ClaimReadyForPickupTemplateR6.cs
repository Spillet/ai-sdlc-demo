namespace Claims.Api.Content.Templates;

public sealed class ClaimReadyForPickupTemplateR6 : IMessageTemplate
{
    public string Key => "claim-ready-for-pickup-6";
    public string Subject => "Reklamace {claimNumber} je připravená k vyzvednutí";
    public string Body =>
        "Dobrý den, zboží z reklamace {claimNumber} k objednávce {orderNumber} si můžete vyzvednout na výdejním místě. Uložené je do {resolveBy}.";
}
