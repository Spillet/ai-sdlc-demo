namespace Claims.Api.Content.Templates;

public sealed class ClaimCourierPickupTemplate : IMessageTemplate
{
    public string Key => "claim-courier-pickup";
    public string Subject => "Reklamace {claimNumber}: kurýr pro zboží přijede";
    public string Body =>
        "Dobrý den, pro reklamované zboží z reklamace {claimNumber} k objednávce {orderNumber} k vám přijede kurýr a zboží si vyzvedne. Reklamaci vyřídíme do {resolveBy}.";
}
