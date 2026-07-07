struct SecureNoteValidator: DomainValidator {
    func validate(_ aggregate: SecureNoteAggregate) throws {
        try aggregate.validateInvariants()
    }
}
