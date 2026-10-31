namespace Claims.Api.Content;

/// <summary>
/// Šablona zákaznické zprávy o reklamaci (předmět a text e-mailu nebo SMS).
/// Nová šablona = nová třída v <c>Content/Templates/</c> a test. Katalog ji najde sám.
/// Zástupné symboly: viz <see cref="MessageCatalog.Placeholders"/>.
/// </summary>
public interface IMessageTemplate
{
    string Key { get; }
    string Subject { get; }
    string Body { get; }
}
