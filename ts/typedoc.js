module.exports = {
  entryPoints: ['./src'],
  includeVersion: true,
  readme: 'README.md',
  sort: ['static-first', 'alphabetical'],
  excludeInternal: true,
  pluginPages: {
    pages: [
      {
        title: 'App Identity for Node.js',
        children: [
          { title: '', source: '../ts/spec.md' },
          { title: 'App Identity Specification', source: '../spec/README.md' },
          { title: 'Changelog', source: './Changelog.md' },
          { title: 'Contributing', source: './Contributing.md' },
          {
            title: 'Licence',
            source: './Licence.md',
            children: [
              {
                title: 'Apache Licence, version 2.0',
                source: './licenses/APACHE-20.txt',
              },
              {
                title: 'Developer Certificate of Origin',
                source: './licenses/dco.txt',
              },
            ],
          },
        ],
      },
    ],
  },
}
