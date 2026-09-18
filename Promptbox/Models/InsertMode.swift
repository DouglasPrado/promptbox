/// Como o prompt chega no app de destino (PRD §37 e §38).
enum InsertMode: Sendable {
    /// Cola o texto e para aí — padrão, para o usuário revisar antes de enviar (PRD §39).
    case insert
    /// Cola e envia.
    case insertAndSend
}
