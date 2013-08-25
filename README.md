minder
======

App usage statistics for OS X

Data format
-----------

Usage data is stored in `.minder-data` in your home directory in Perl Storable format. The data structure within is like this:

```
{
    '20130823' => {
        ... data ...
    },
    '20130824' => {
        'iTerm' => {
            '22:18' => 6.0,
            '22:19' => 0.5,
            '22:21' => 7.5,
            '22:24' => 4.5,
            '22:32' => 3.4,
            '22:35' => 7.8,
            '22:36' => 14.9,
            '22:41' => 18.8,
            '22:42' => 10.3,
            'total' => 73.7
        },
        'Messages' => {
            "22:36" => 25.2,
            "total" => 25.2
        }
    },
    '20130825' => {
        ... data ...
    }
}
```
