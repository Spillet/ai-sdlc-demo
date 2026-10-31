namespace Claims.Api.Content.Templates;

public sealed class ClaimResolvedTemplate : IMessageTemplate
{
    public string Key => "claim-resolved";
    public string Subject => "Reklamace {claimNumber} je vyřízená";
    public string Body =>
        "Dobrý den, reklamaci {claimNumber} k objednávce {orderNumber} jsme vyřídili. Podrobnosti najdete v zákaznickém účtu.";
}
