declare module "virtual:*" {
  const config: {
    nodes: {
      requiredApiVersion: string;
      fallbackPublicExplorer: string;
      defaultHttpdPort: number;
      defaultLocalHttpdPort: number;
      defaultHttpdScheme: string;
    };
    source: {
      commitsPerPage: number;
    };
    deploymentId: string | null;
    reactions: string[];
    supportWebsite: string;
    preferredSeeds: BaseUrl[];
    namedRepositories: Record<string, string>;
  };

  export default config;
}
