namespace Claims.Api.Content.Templates;

public sealed class ClaimSentToServiceTemplate : IMessageTemplate
{
    public string Key => "claim-sent-to-service";
    public string Subject => "Reklamace {claimNumber} je v servisu";
    public string Body =>
        "Dobrý den, zboží z reklamace {claimNumber} k objednávce {orderNumber} jsme předali do autorizovaného servisu. Vyřídíme ji nejpozději do {resolveBy}.";
}
