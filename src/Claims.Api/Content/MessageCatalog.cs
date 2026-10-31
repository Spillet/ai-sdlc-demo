namespace Claims.Api.Content;

public sealed record RenderedMessage(string Key, string Subject, string Body);

/// <summary>
/// Katalog šablon zákaznických zpráv. Jen texty: nemění peníze ani zákonná pravidla,
/// proto je Content/ v risk policy bezpečná oblast (profil normal ji pustí do auto-merge).
/// </summary>
public static class MessageCatalog
{
    public static readonly IReadOnlyList<string> Placeholders = ["orderNumber", "claimNumber", "resolveBy"];

    private static readonly Lazy<Dictionary<string, IMessageTemplate>> ByKey = new(Load);

    public static IEnumerable<IMessageTemplate> All =>
        ByKey.Value.Values.OrderBy(t => t.Key, StringComparer.Ordinal);

    public static IMessageTemplate? Find(string key) =>
        ByKey.Value.TryGetValue(key, out var template) ? template : null;

    public static RenderedMessage Render(IMessageTemplate template, IReadOnlyDictionary<string, string> values)
    {
        var subject = template.Subject;
        var body = template.Body;
        foreach (var name in Placeholders)
        {
            var value = values.TryGetValue(name, out var found) ? found : "";
            subject = subject.Replace("{" + name + "}", value, StringComparison.Ordinal);
            body = body.Replace("{" + name + "}", value, StringComparison.Ordinal);
        }
        return new RenderedMessage(template.Key, subject, body);
    }

    private static Dictionary<string, IMessageTemplate> Load()
    {
        var result = new Dictionary<string, IMessageTemplate>(StringComparer.Ordinal);
        var types = typeof(MessageCatalog).Assembly.GetTypes()
            .Where(t => t is { IsClass: true, IsAbstract: false } && typeof(IMessageTemplate).IsAssignableFrom(t));
        foreach (var type in types)
        {
            var template = (IMessageTemplate)Activator.CreateInstance(type)!;
            if (!result.TryAdd(template.Key, template))
            {
                throw new InvalidOperationException($"Duplicitní klíč šablony: {template.Key}");
            }
        }
        return result;
    }
}
