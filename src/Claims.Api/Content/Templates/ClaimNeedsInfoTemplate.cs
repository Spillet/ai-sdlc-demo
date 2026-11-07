namespace Claims.Api.Content.Templates;

public sealed class ClaimNeedsInfoTemplate : IMessageTemplate
{
    public string Key => "claim-needs-info";
    public string Subject => "Reklamace {claimNumber}: potřebujeme doplnit údaje";
    public string Body =>
        "Dobrý den, k reklamaci {claimNumber} (objednávka {orderNumber}) potřebujeme fotku a popis vady. Pošlete je prosím odpovědí na tento e-mail. Lhůta na vyřízení běží do {resolveBy}.";
}
