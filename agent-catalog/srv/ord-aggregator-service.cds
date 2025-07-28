@protocol: ['rest']
@path    : '/ord-aggregator'
@impl    : './ord-aggregator-service.ts'
service ORDAggregator {
    // TODO: define custom type for return

    type AgentCapability {
        streaming              : Boolean;
        pushNotifications      : Boolean;
        stateTransitionHistory : Boolean;
    }

    type AgentSkill {
        id          : String;
        name        : String;
        description : String;
        tags        : array of String;
        examples    : array of String;
        outputModes : array of String;
    }

    type AgentInfo {
        name               : String;
        description        : String;
        url                : String;
        version            : String;
        defaultInputModes  : array of String;
        defaultOutputModes : array of String;
        capabilities       : AgentCapability;
        skills             : array of AgentSkill;
    }

    type AgentCatalogEntry {
        ordVersion   : String;
        ordDocUrl    : String;
        provider     : String;
        agentCardUrl : String;
        agent        : AgentInfo;
    }

    function listAgentsCatalog()                          returns array of AgentCatalogEntry;

    action   metadata(
                      @mandatory
                      tenantId: String not null,
                      @mandatory
                      agentId: String not null,
                      @mandatory
                      chatId: String not null,
                      @mandatory
                      toolId: String not null)            returns {
        name        : String;
        description : String;
        schema      : String;
    };

    action   callback(
                      @mandatory
                      toolInput: String not null,
                      @mandatory
                      tenantId: String not null,
                      @mandatory
                      agentId: String not null,
                      @mandatory
                      chatId: String not null,
                      @mandatory
                      toolId: String not null,
                      @mandatory
                      callbackHistoryId: String not null) returns {
        response : String;
    };
}
