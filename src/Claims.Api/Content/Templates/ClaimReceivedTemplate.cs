namespace Claims.Api.Content.Templates;

public sealed class ClaimReceivedTemplate : IMessageTemplate
{
    public string Key => "claim-received";
    public string Subject => "Reklamaci {claimNumber} jsme přijali";
    public string Body =>
        "Dobrý den, reklamaci {claimNumber} k objednávce {orderNumber} jsme přijali. Vyřídíme ji nejpozději do {resolveBy}.";
}
